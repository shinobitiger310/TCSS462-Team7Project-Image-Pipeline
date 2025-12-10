#!/usr/bin/env python3
"""
Generate Combined Comparison Report from Experiment Results
Reads all CSV files from results directory and creates unified comparison
"""

import pandas as pd
import sys
import os
import glob

def calculate_stats(df):
    """Calculate statistics from dataframe"""
    stats = {
        'mean': df['runtime'].mean(),
        'std': df['runtime'].std(),
        'median': df['runtime'].median(),
        'min': df['runtime'].min(),
        'max': df['runtime'].max(),
        'count': len(df)
    }
    return stats

def main():
    if len(sys.argv) < 2:
        print("Usage: ./generate_comparison_report.py <results_directory>")
        print("Example: ./generate_comparison_report.py ./results_20241209_150322")
        sys.exit(1)

    results_dir = sys.argv[1]

    if not os.path.exists(results_dir):
        print(f"Error: Directory {results_dir} does not exist")
        sys.exit(1)

    print("=" * 70)
    print("  Multi-Language Comparison Report")
    print("=" * 70)
    print()

    # Find all result directories
    languages = ['python', 'java', 'nodejs']
    functions = ['rotate', 'resize', 'greyscale', 'grayscale']  # grayscale for Java

    results = {}

    for lang in languages:
        results[lang] = {}
        for func in functions:
            # Try different naming conventions
            patterns = [
                f"{results_dir}/{lang}_{func}/language_comparison_zAll.csv",
                f"{results_dir}/{lang}_{func}/*_zAll.csv"
            ]

            for pattern in patterns:
                files = glob.glob(pattern)
                if files:
                    try:
                        df = pd.read_csv(files[0])
                        if 'runtime' in df.columns:
                            results[lang][func] = calculate_stats(df)
                            print(f"✓ Loaded: {lang}_{func}")
                            break
                    except Exception as e:
                        print(f"✗ Error reading {files[0]}: {e}")

    print()
    print("=" * 70)
    print("  Average Runtime Comparison (ms)")
    print("=" * 70)
    print()

    # Print table
    print(f"{'Language':<12} | {'Rotate':<8} | {'Resize':<8} | {'Grayscale':<10} | {'Total':<10}")
    print("-" * 70)

    for lang in languages:
        lang_name = lang.capitalize()

        # Get function names (handle grayscale vs greyscale)
        rotate_key = 'rotate' if 'rotate' in results[lang] else None
        resize_key = 'resize' if 'resize' in results[lang] else None
        grey_key = 'greyscale' if 'greyscale' in results[lang] else ('grayscale' if 'grayscale' in results[lang] else None)

        rotate_time = results[lang][rotate_key]['mean'] if rotate_key and rotate_key in results[lang] else 0
        resize_time = results[lang][resize_key]['mean'] if resize_key and resize_key in results[lang] else 0
        grey_time = results[lang][grey_key]['mean'] if grey_key and grey_key in results[lang] else 0
        total_time = rotate_time + resize_time + grey_time

        print(f"{lang_name:<12} | {rotate_time:>6.1f}ms | {resize_time:>6.1f}ms | {grey_time:>8.1f}ms | {total_time:>8.1f}ms")

    print()
    print("=" * 70)
    print("  Detailed Statistics")
    print("=" * 70)
    print()

    for lang in languages:
        print(f"\n{lang.upper()} Details:")
        print("-" * 50)

        for func in results[lang]:
            stats = results[lang][func]
            print(f"\n  {func.capitalize()}:")
            print(f"    Mean:   {stats['mean']:.2f} ms")
            print(f"    Std:    {stats['std']:.2f} ms")
            print(f"    Median: {stats['median']:.2f} ms")
            print(f"    Min:    {stats['min']:.2f} ms")
            print(f"    Max:    {stats['max']:.2f} ms")
            print(f"    Runs:   {stats['count']}")

    # Save to file
    output_file = os.path.join(results_dir, "comparison_summary.txt")
    with open(output_file, 'w') as f:
        f.write("Multi-Language Comparison Report\n")
        f.write("=" * 70 + "\n\n")

        f.write("Average Runtime (ms)\n")
        f.write("-" * 70 + "\n")
        f.write(f"{'Language':<12} | {'Rotate':<8} | {'Resize':<8} | {'Grayscale':<10} | {'Total':<10}\n")
        f.write("-" * 70 + "\n")

        for lang in languages:
            lang_name = lang.capitalize()
            rotate_key = 'rotate' if 'rotate' in results[lang] else None
            resize_key = 'resize' if 'resize' in results[lang] else None
            grey_key = 'greyscale' if 'greyscale' in results[lang] else ('grayscale' if 'grayscale' in results[lang] else None)

            rotate_time = results[lang][rotate_key]['mean'] if rotate_key and rotate_key in results[lang] else 0
            resize_time = results[lang][resize_key]['mean'] if resize_key and resize_key in results[lang] else 0
            grey_time = results[lang][grey_key]['mean'] if grey_key and grey_key in results[lang] else 0
            total_time = rotate_time + resize_time + grey_time

            f.write(f"{lang_name:<12} | {rotate_time:>6.1f}ms | {resize_time:>6.1f}ms | {grey_time:>8.1f}ms | {total_time:>8.1f}ms\n")

        f.write("\n" + "=" * 70 + "\n")
        f.write("Detailed Statistics\n")
        f.write("=" * 70 + "\n")

        for lang in languages:
            f.write(f"\n{lang.upper()} Details:\n")
            f.write("-" * 50 + "\n")

            for func in results[lang]:
                stats = results[lang][func]
                f.write(f"\n  {func.capitalize()}:\n")
                f.write(f"    Mean:   {stats['mean']:.2f} ms\n")
                f.write(f"    Std:    {stats['std']:.2f} ms\n")
                f.write(f"    Median: {stats['median']:.2f} ms\n")
                f.write(f"    Min:    {stats['min']:.2f} ms\n")
                f.write(f"    Max:    {stats['max']:.2f} ms\n")
                f.write(f"    Runs:   {stats['count']}\n")

    print()
    print("=" * 70)
    print(f"  Report saved to: {output_file}")
    print("=" * 70)
    print()

if __name__ == "__main__":
    main()
