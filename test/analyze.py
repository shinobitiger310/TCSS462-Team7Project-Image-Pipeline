import boto3
import json
import time
import re
from datetime import datetime, timedelta
from statistics import mean, stdev

def parse_test_results_file(filename):
    """Parse the test_results file to extract test metadata"""
    
    tests = []
    
    with open(filename, 'r') as f:
        content = f.read()
    
    # Find all test blocks
    pattern = r'Testing: (\w+) with concurrency (\d+).*?(?:âœ" Upload complete!|Upload complete!).*?Uploaded (\d+) images in (\d+)s'
    matches = re.finditer(pattern, content, re.DOTALL)
    
    for match in matches:
        language = match.group(1)
        concurrency = int(match.group(2))
        batch_size = int(match.group(3))
        duration = int(match.group(4))
        
        tests.append({
            'language': language,
            'concurrency': concurrency,
            'batch_size': batch_size,
            'upload_duration': duration
        })
    
    return tests

def query_cloudwatch_logs(log_group_name, query_string, start_time, end_time, max_wait=60):
    """Execute a CloudWatch Logs Insights query and wait for results"""
    
    client = boto3.client('logs', region_name='us-east-2')
    
    try:
        response = client.start_query(
            logGroupName=log_group_name,
            startTime=int(start_time.timestamp()),
            endTime=int(end_time.timestamp()),
            queryString=query_string
        )
    except client.exceptions.ResourceNotFoundException:
        return None
    
    query_id = response['queryId']
    
    waited = 0
    while waited < max_wait:
        result = client.get_query_results(queryId=query_id)
        status = result['status']
        
        if status == 'Complete':
            return result['results']
        elif status == 'Failed':
            return None
        
        time.sleep(2)
        waited += 2
    
    return None

def analyze_lambda_performance(function_name, start_time, end_time):
    """Analyze Lambda performance for a specific time window"""
    
    query = '''
    fields @timestamp, @message, @type
    | filter @type = "REPORT"
    | parse @message /Duration:\\s*(?<DurationMS>[\\d.]+)\\s*ms/
    | parse @message /Billed Duration:\\s*(?<BilledDuration>\\d+)\\s*ms/
    | parse @message /Max Memory Used:\\s*(?<MemoryUsed>\\d+)\\s*MB/
    | parse @message /Memory Size:\\s*(?<MemorySize>\\d+)\\s*MB/
    | parse @message /Init Duration:\\s*(?<InitDuration>[\\d.]+)\\s*ms/
    | sort @timestamp asc
    '''
    
    results = query_cloudwatch_logs(
        f'/aws/lambda/{function_name}',
        query,
        start_time,
        end_time
    )
    
    if not results:
        return None
    
    durations = []
    billed_durations = []
    memory_used = []
    memory_size = None
    timestamps = []
    cold_starts = 0
    
    for row in results:
        fields_dict = {item['field']: item['value'] for item in row}
        
        if fields_dict.get('DurationMS'):
            durations.append(float(fields_dict['DurationMS']))
            timestamps.append(datetime.fromisoformat(fields_dict['@timestamp'].replace('Z', '+00:00')))
        
        if fields_dict.get('BilledDuration'):
            billed_durations.append(int(fields_dict['BilledDuration']))
        
        if fields_dict.get('MemoryUsed'):
            memory_used.append(int(fields_dict['MemoryUsed']))
        
        if fields_dict.get('MemorySize') and memory_size is None:
            memory_size = int(fields_dict['MemorySize'])
        
        if fields_dict.get('InitDuration'):
            cold_starts += 1
    
    if not durations:
        return None
    
    batch_duration_s = (max(timestamps) - min(timestamps)).total_seconds()
    
    return {
        'function': function_name,
        'invocations': len(durations),
        'cold_starts': cold_starts,
        'warm_starts': len(durations) - cold_starts,
        'avg_duration_ms': mean(durations),
        'stddev_duration_ms': stdev(durations) if len(durations) > 1 else 0,
        'cv': stdev(durations) / mean(durations) if len(durations) > 1 and mean(durations) > 0 else 0,
        'min_duration_ms': min(durations),
        'max_duration_ms': max(durations),
        'avg_billed_ms': mean(billed_durations) if billed_durations else None,
        'avg_memory_mb': mean(memory_used) if memory_used else None,
        'memory_size_mb': memory_size,
        'batch_duration_s': batch_duration_s,
        'throughput_inv_per_s': len(durations) / batch_duration_s if batch_duration_s > 0 else 0,
        'first_invocation': min(timestamps).isoformat(),
        'last_invocation': max(timestamps).isoformat()
    }

def format_scalability_report(results_by_concurrency):
    """Generate scalability comparison report"""
    
    report = []
    report.append("=" * 100)
    report.append("LAMBDA SCALABILITY ANALYSIS REPORT")
    report.append("=" * 100)
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")
    
    # Summary table by language
    for lang in ['python', 'java', 'javascript']:
        report.append("")
        report.append("=" * 100)
        report.append(f"{lang.upper()} - SCALABILITY ACROSS CONCURRENCY LEVELS")
        report.append("=" * 100)
        report.append("")
        report.append(f"{'Concur.':<8} {'Batch':<7} {'Invocs':<8} {'Avg RT (ms)':<12} {'StdDev':<10} {'CV':<8} {'Cold %':<8} {'Throughput':<12} {'Timeouts':<10}")
        report.append("-" * 100)
        
        for concurrency in sorted(results_by_concurrency.keys()):
            if lang not in results_by_concurrency[concurrency]:
                continue
            
            data = results_by_concurrency[concurrency][lang]
            stages = data['stages']
            valid_stages = [s for s in stages.values() if s]
            
            if not valid_stages:
                continue
            
            # Calculate aggregates
            total_invocations = sum([s['invocations'] for s in valid_stages])
            avg_runtime = mean([s['avg_duration_ms'] for s in valid_stages])
            avg_stddev = mean([s['stddev_duration_ms'] for s in valid_stages])
            avg_cv = mean([s['cv'] for s in valid_stages])
            total_cold = sum([s['cold_starts'] for s in valid_stages])
            cold_pct = (total_cold / total_invocations * 100) if total_invocations > 0 else 0
            
            # Throughput
            all_times = []
            for s in valid_stages:
                all_times.append(datetime.fromisoformat(s['first_invocation']))
                all_times.append(datetime.fromisoformat(s['last_invocation']))
            
            if all_times:
                duration = (max(all_times) - min(all_times)).total_seconds()
                images = total_invocations / 3
                throughput = images / duration if duration > 0 else 0
            else:
                throughput = 0
            
            # Check timeouts
            max_durations = [s['max_duration_ms'] for s in valid_stages]
            timeouts = "YES" if any(d >= 3000 for d in max_durations) else "NO"
            
            batch_size = data['batch_size']
            
            report.append(f"{concurrency:<8} {batch_size:<7} {total_invocations:<8} {avg_runtime:<12.2f} {avg_stddev:<10.2f} {avg_cv:<8.4f} {cold_pct:<8.1f} {throughput:<12.2f} {timeouts:<10}")
        
        report.append("")
    
    # Detailed per-stage breakdown
    report.append("\n" + "=" * 100)
    report.append("DETAILED BREAKDOWN BY CONCURRENCY AND STAGE")
    report.append("=" * 100)
    
    for concurrency in sorted(results_by_concurrency.keys()):
        report.append(f"\n\nCONCURRENCY LEVEL: {concurrency}")
        report.append("=" * 100)
        
        for lang in ['python', 'java', 'javascript']:
            if lang not in results_by_concurrency[concurrency]:
                continue
            
            data = results_by_concurrency[concurrency][lang]
            stages = data['stages']
            
            report.append(f"\n{lang.upper()}:")
            report.append("-" * 100)
            
            for stage_name in ['rotate', 'resize', 'greyscale']:
                metrics = stages.get(stage_name)
                
                if not metrics:
                    report.append(f"\n  {stage_name}: NO DATA")
                    continue
                
                report.append(f"\n  {stage_name}:")
                report.append(f"    Invocations: {metrics['invocations']}")
                report.append(f"    Cold Starts: {metrics['cold_starts']} ({metrics['cold_starts']/metrics['invocations']*100:.1f}%)")
                report.append(f"    Avg Runtime: {metrics['avg_duration_ms']:.2f} ms")
                report.append(f"    Std Dev: {metrics['stddev_duration_ms']:.2f} ms")
                report.append(f"    CV: {metrics['cv']:.4f}")
                report.append(f"    Min/Max: {metrics['min_duration_ms']:.2f} / {metrics['max_duration_ms']:.2f} ms")
                report.append(f"    Memory: {metrics['avg_memory_mb']:.1f} MB / {metrics['memory_size_mb']} MB ({metrics['avg_memory_mb']/metrics['memory_size_mb']*100:.1f}%)")
                
                if metrics['max_duration_ms'] >= 3000:
                    report.append(f"    ⚠ TIMEOUT WARNING")
    
    report.append("\n\n" + "=" * 100)
    report.append("END OF REPORT")
    report.append("=" * 100)
    
    return "\n".join(report)

def main():
    """Main analysis function"""
    
    functions = {
        'python': {
            'rotate': 'python_lambda_rotate',
            'resize': 'python_lambda_resize',
            'greyscale': 'python_lambda_greyscale'
        },
        'java': {
            'rotate': 'rotateJava',
            'resize': 'resizeJava',
            'greyscale': 'grayJava'
        },
        'javascript': {
            'rotate': 'nodejs_lambda_rotate',
            'resize': 'nodejs_lambda_resize',
            'greyscale': 'nodejs_lambda_grayscale'
        }
    }
    
    print("=" * 100)
    print("SCALABILITY ANALYSIS")
    print("=" * 100)
    print("")
    
    # Get time window for entire test suite
    print("Enter the time window that covers ALL your tests:")
    print("(This should span from first Python test to last JavaScript test)")
    print("")
    
    start_input = input("Start time (YYYY-MM-DD HH:MM:SS UTC) [2025-12-12 00:00:00]: ").strip()
    end_input = input("End time   (YYYY-MM-DD HH:MM:SS UTC) [2025-12-12 03:00:00]: ").strip()
    
    start_time = datetime.strptime(start_input or "2025-12-12 00:00:00", '%Y-%m-%d %H:%M:%S')
    end_time = datetime.strptime(end_input or "2025-12-12 03:00:00", '%Y-%m-%d %H:%M:%S')
    
    print(f"\nAnalyzing from {start_time} to {end_time}")
    print("")
    
    # Concurrency levels tested
    concurrency_levels = [1, 5, 10, 50, 100]
    batch_size = 100
    
    results_by_concurrency = {}
    
    for concurrency in concurrency_levels:
        print(f"\nAnalyzing Concurrency = {concurrency}...")
        results_by_concurrency[concurrency] = {}
        
        for lang, func_dict in functions.items():
            print(f"  {lang}...", end=" ", flush=True)
            
            results_by_concurrency[concurrency][lang] = {
                'batch_size': batch_size,
                'concurrency': concurrency,
                'stages': {}
            }
            
            for stage, func_name in func_dict.items():
                metrics = analyze_lambda_performance(func_name, start_time, end_time)
                results_by_concurrency[concurrency][lang]['stages'][stage] = metrics
            
            print("✓")
    
    # Generate report
    print("\n" + "=" * 100)
    print("Generating scalability report...")
    
    report_text = format_scalability_report(results_by_concurrency)
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"scalability_report_{timestamp}.txt"
    
    with open(filename, 'w') as f:
        f.write(report_text)
    
    print(f"✓ Report saved to: {filename}")
    print("\n" + report_text)
    
    # Save raw data
    json_filename = f"scalability_data_{timestamp}.json"
    with open(json_filename, 'w') as f:
        json.dump(results_by_concurrency, f, indent=2, default=str)
    
    print(f"\n✓ Raw data saved to: {json_filename}")

if __name__ == '__main__':
    main()