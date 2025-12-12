import boto3
import json
import time
from datetime import datetime
from statistics import mean, stdev

def load_test_metadata(metadata_file):
    """Load test metadata from JSON file"""
    
    with open(metadata_file, 'r') as f:
        data = json.load(f)
    
    return data['tests']

def query_cloudwatch_logs(log_group_name, query_string, start_time, end_time, max_wait=60):
    """Execute CloudWatch Logs Insights query"""
    
    client = boto3.client('logs', region_name='us-east-2')
    
    try:
        response = client.start_query(
            logGroupName=log_group_name,
            startTime=int(start_time.timestamp()),
            endTime=int(end_time.timestamp()),
            queryString=query_string
        )
    except Exception as e:
        print(f"    Error: {e}")
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
    """Analyze Lambda performance for specific time window"""
    
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
    
    return {
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
        'memory_size_mb': memory_size
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
        report.append(f"{'Concur.':<8} {'Batch':<7} {'Invocs':<8} {'Avg RT (ms)':<12} {'StdDev':<10} {'CV':<8} {'Cold %':<8} {'Max (ms)':<12}")
        report.append("-" * 100)
        
        for concurrency in sorted([k for k in results_by_concurrency.keys() if isinstance(k, int)]):
            if lang not in results_by_concurrency[concurrency]:
                continue
            
            data = results_by_concurrency[concurrency][lang]
            stages = data['stages']
            valid_stages = [s for s in stages.values() if s]
            
            if not valid_stages:
                report.append(f"{concurrency:<8} {data['batch_size']:<7} {'NO DATA':<60}")
                continue
            
            # Calculate aggregates across all 3 stages
            total_invocations = sum([s['invocations'] for s in valid_stages])
            avg_runtime = mean([s['avg_duration_ms'] for s in valid_stages])
            avg_stddev = mean([s['stddev_duration_ms'] for s in valid_stages])
            avg_cv = mean([s['cv'] for s in valid_stages])
            total_cold = sum([s['cold_starts'] for s in valid_stages])
            cold_pct = (total_cold / total_invocations * 100) if total_invocations > 0 else 0
            max_runtime = max([s['max_duration_ms'] for s in valid_stages])
            
            batch_size = data['batch_size']
            
            report.append(f"{concurrency:<8} {batch_size:<7} {total_invocations:<8} {avg_runtime:<12.2f} {avg_stddev:<10.2f} {avg_cv:<8.4f} {cold_pct:<8.1f} {max_runtime:<12.2f}")
        
        report.append("")
    
    # Detailed breakdown
    report.append("\n" + "=" * 100)
    report.append("DETAILED BREAKDOWN BY CONCURRENCY AND STAGE")
    report.append("=" * 100)
    
    for concurrency in sorted([k for k in results_by_concurrency.keys() if isinstance(k, int)]):
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
                if metrics['avg_memory_mb'] and metrics['memory_size_mb']:
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
        'Python': {
            'rotate': 'python_lambda_rotate',
            'resize': 'python_lambda_resize',
            'greyscale': 'python_lambda_greyscale'
        },
        'Java': {
            'rotate': 'rotateJava',
            'resize': 'resizeJava',
            'greyscale': 'grayJava'
        },
        'JavaScript': {
            'rotate': 'nodejs_lambda_rotate',
            'resize': 'nodejs_lambda_resize',
            'greyscale': 'nodejs_lambda_grayscale'
        }
    }
    
    print("=" * 100)
    print("SCALABILITY ANALYSIS - Using Test Metadata")
    print("=" * 100)
    print("")
    
    # Get metadata file
    metadata_file = input("Enter metadata filename: ").strip()
    
    print(f"\nLoading {metadata_file}...")
    tests = load_test_metadata(metadata_file)
    print(f"✓ Loaded {len(tests)} test runs")
    print("")
    
    # Display test schedule
    print("Test Schedule:")
    for test in tests:
        print(f"  {test['language']:<12} concurrency={test['concurrency']:<3} : {test['start_time']} to {test['end_time']}")
    
    print("\nQuerying CloudWatch for each test...")
    
    results_by_concurrency = {}
    
    for test in tests:
        concurrency = test['concurrency']
        language = test['language']
        
        start_time = datetime.strptime(test['start_time'], '%Y-%m-%d %H:%M:%S')
        end_time = datetime.strptime(test['end_time'], '%Y-%m-%d %H:%M:%S')
        
        print(f"\n{language:<12} @ concurrency {concurrency:<3} ... ", end="", flush=True)
        
        if concurrency not in results_by_concurrency:
            results_by_concurrency[concurrency] = {}
        
        lang_key = language.lower()
        results_by_concurrency[concurrency][lang_key] = {
            'batch_size': test['batch_size'],
            'concurrency': concurrency,
            'stages': {}
        }
        
        for stage, func_name in functions[language].items():
            metrics = analyze_lambda_performance(func_name, start_time, end_time)
            results_by_concurrency[concurrency][lang_key]['stages'][stage] = metrics
        
        # Show quick summary
        stages = results_by_concurrency[concurrency][lang_key]['stages']
        valid = [s for s in stages.values() if s]
        if valid:
            total = sum(s['invocations'] for s in valid)
            print(f"✓ ({total} invocations)")
        else:
            print("✗ (no data)")
    
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