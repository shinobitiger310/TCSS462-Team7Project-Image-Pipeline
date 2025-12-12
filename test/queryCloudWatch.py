import boto3
import json
import time
from datetime import datetime, timedelta
from statistics import mean, stdev

def query_cloudwatch_logs(log_group_name, query_string, start_time, end_time, max_wait=60):
    """Execute a CloudWatch Logs Insights query and wait for results"""
    
    client = boto3.client('logs', region_name='us-east-2')
    
    response = client.start_query(
        logGroupName=log_group_name,
        startTime=int(start_time.timestamp()),
        endTime=int(end_time.timestamp()),
        queryString=query_string
    )
    
    query_id = response['queryId']
    
    # Wait for query to complete
    waited = 0
    while waited < max_wait:
        result = client.get_query_results(queryId=query_id)
        status = result['status']
        
        if status == 'Complete':
            return result['results']
        elif status == 'Failed':
            raise Exception(f'Query failed for {log_group_name}')
        
        time.sleep(2)
        waited += 2
    
    raise Exception(f'Query timed out after {max_wait}s')

def analyze_lambda_performance(function_name, minutes_ago=15):
    """Analyze Lambda performance using only automatic logs"""
    
    # Fixed query - removed duplicate Duration field definition
    query = '''
    fields @timestamp, @message, @type, @requestId
    | filter @type = "REPORT"
    | parse @message /Duration:\\s*(?<DurationMS>[\\d.]+)\\s*ms/
    | parse @message /Billed Duration:\\s*(?<BilledDuration>\\d+)\\s*ms/
    | parse @message /Max Memory Used:\\s*(?<MemoryUsed>\\d+)\\s*MB/
    | parse @message /Memory Size:\\s*(?<MemorySize>\\d+)\\s*MB/
    | parse @message /Init Duration:\\s*(?<InitDuration>[\\d.]+)\\s*ms/
    | sort @timestamp asc
    '''
    
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=minutes_ago)
    
    print(f"Querying {function_name}...")
    
    try:
        results = query_cloudwatch_logs(
            f'/aws/lambda/{function_name}',
            query,
            start_time,
            end_time
        )
    except Exception as e:
        print(f"  Error: {e}")
        return None
    
    if not results:
        print(f"  No data found")
        return None
    
    # Parse results
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
        print(f"  No valid data")
        return None
    
    # Calculate metrics
    batch_duration_s = (max(timestamps) - min(timestamps)).total_seconds()
    
    metrics = {
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
    
    print(f"  ✓ Found {len(durations)} invocations")
    
    return metrics

def calculate_cost(metrics):
    """Calculate Lambda cost based on billed duration and memory"""
    
    if not metrics or not metrics.get('avg_billed_ms') or not metrics.get('memory_size_mb'):
        return None
    
    # AWS Lambda pricing: $0.0000166667 per GB-second
    # Plus $0.20 per 1M requests
    
    gb_seconds = (metrics['avg_billed_ms'] / 1000) * (metrics['memory_size_mb'] / 1024)
    compute_cost_per_invocation = gb_seconds * 0.0000166667
    request_cost_per_invocation = 0.0000002  # $0.20 / 1M requests
    
    total_cost_per_invocation = compute_cost_per_invocation + request_cost_per_invocation
    
    return {
        'cost_per_invocation': total_cost_per_invocation,
        'cost_per_100k_invocations': total_cost_per_invocation * 100000,
        'compute_cost_per_inv': compute_cost_per_invocation,
        'request_cost_per_inv': request_cost_per_invocation
    }

def format_report(all_metrics):
    """Format metrics into a readable report"""
    
    report = []
    report.append("=" * 80)
    report.append("LAMBDA PERFORMANCE ANALYSIS REPORT")
    report.append("=" * 80)
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")
    
    for lang, functions in all_metrics.items():
        report.append("")
        report.append("=" * 80)
        report.append(f"{lang.upper()} PIPELINE")
        report.append("=" * 80)
        
        total_invocations = sum(f['invocations'] for f in functions.values() if f)
        images_processed = total_invocations / 3 if total_invocations > 0 else 0
        
        report.append("")
        report.append(f"Pipeline Overview:")
        report.append(f"  Total Invocations: {total_invocations}")
        report.append(f"  Images Processed: {images_processed:.0f}")
        
        # Calculate overall throughput
        all_timestamps = []
        for func_metrics in functions.values():
            if func_metrics:
                all_timestamps.append(datetime.fromisoformat(func_metrics['first_invocation']))
                all_timestamps.append(datetime.fromisoformat(func_metrics['last_invocation']))
        
        if all_timestamps:
            pipeline_duration = (max(all_timestamps) - min(all_timestamps)).total_seconds()
            overall_throughput = images_processed / pipeline_duration if pipeline_duration > 0 else 0
            report.append(f"  Pipeline Duration: {pipeline_duration:.2f}s")
            report.append(f"  Overall Throughput: {overall_throughput:.2f} images/second")
        
        report.append("")
        
        # Per-function breakdown
        for func_name, metrics in functions.items():
            if not metrics:
                report.append(f"\n{func_name}: NO DATA")
                continue
            
            report.append("")
            report.append(f"{func_name}:")
            report.append(f"  Invocations: {metrics['invocations']}")
            report.append(f"  Cold Starts: {metrics['cold_starts']} ({metrics['cold_starts']/metrics['invocations']*100:.1f}%)")
            report.append(f"  Warm Starts: {metrics['warm_starts']} ({metrics['warm_starts']/metrics['invocations']*100:.1f}%)")
            report.append("")
            report.append(f"  Runtime Statistics:")
            report.append(f"    Average: {metrics['avg_duration_ms']:.2f} ms")
            report.append(f"    Std Dev: {metrics['stddev_duration_ms']:.2f} ms")
            report.append(f"    CV: {metrics['cv']:.4f}")
            report.append(f"    Min: {metrics['min_duration_ms']:.2f} ms")
            report.append(f"    Max: {metrics['max_duration_ms']:.2f} ms")
            report.append("")
            report.append(f"  Billing:")
            report.append(f"    Avg Billed Duration: {metrics['avg_billed_ms']:.2f} ms")
            report.append(f"    Memory Size: {metrics['memory_size_mb']} MB")
            report.append(f"    Avg Memory Used: {metrics['avg_memory_mb']:.2f} MB ({metrics['avg_memory_mb']/metrics['memory_size_mb']*100:.1f}%)")
            
            # Cost calculation
            cost = calculate_cost(metrics)
            if cost:
                report.append("")
                report.append(f"  Cost Estimates:")
                report.append(f"    Per Invocation: ${cost['cost_per_invocation']:.8f}")
                report.append(f"    Per 100k Invocations: ${cost['cost_per_100k_invocations']:.4f}")
    
    report.append("")
    report.append("=" * 80)
    report.append("END OF REPORT")
    report.append("=" * 80)
    
    return "\n".join(report)

def main():
    """Main function to analyze all Lambda functions"""
    
    # Define your actual Lambda function names
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
    
    # Adjust this based on when you ran your tests
    minutes_ago = 120  # Look back 120 minutes
    
    print("=" * 80)
    print("Starting CloudWatch Logs Analysis")
    print("=" * 80)
    print(f"Looking back {minutes_ago} minutes")
    print("")
    
    all_metrics = {}
    
    for lang, func_dict in functions.items():
        print(f"\nAnalyzing {lang.upper()}...")
        all_metrics[lang] = {}
        
        for stage, func_name in func_dict.items():
            metrics = analyze_lambda_performance(func_name, minutes_ago)
            all_metrics[lang][stage] = metrics
    
    # Generate report
    print("\n" + "=" * 80)
    print("Generating report...")
    
    report_text = format_report(all_metrics)
    
    # Save to file
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"lambda_performance_report_{timestamp}.txt"
    
    with open(filename, 'w') as f:
        f.write(report_text)
    
    print(f"✓ Report saved to: {filename}")
    
    # Also print to console
    print("\n" + report_text)
    
    # Save raw data as JSON
    json_filename = f"lambda_performance_data_{timestamp}.json"
    with open(json_filename, 'w') as f:
        json.dump(all_metrics, f, indent=2, default=str)
    
    print(f"✓ Raw data saved to: {json_filename}")

if __name__ == '__main__':
    main()