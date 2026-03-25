#!/usr/bin/env python3
import json
import os
import re
import sys

def check_translations():
    l10n_dir = 'lib/l10n'
    template_file = 'app_en.arb'
    template_path = os.path.join(l10n_dir, template_file)

    if not os.path.exists(template_path):
        print(f"Error: Template file {template_path} not found.")
        sys.exit(1)

    with open(template_path, 'r') as f:
        template_data = json.load(f)

    template_keys = set(k for k in template_data.keys() if not k.startswith('@'))
    template_meta = set(k for k in template_data.keys() if k.startswith('@') and k != '@@locale')

    all_files = [f for f in os.listdir(l10n_dir) if f.endswith('.arb') and f != template_file]
    
    total_errors = 0

    for filename in sorted(all_files):
        print(f"\n--- Checking {filename} ---")
        errors = 0
        path = os.path.join(l10n_dir, filename)
        with open(path, 'r') as f:
            data = json.load(f)

        keys = set(k for k in data.keys() if not k.startswith('@'))
        meta = set(k for k in data.keys() if k.startswith('@') and k != '@@locale')

        # 1. Check for missing/extra keys
        missing = template_keys - keys
        extra = keys - template_keys
        if missing:
            print(f"  [MISSING KEYS]: {sorted(list(missing))}")
            errors += len(missing)
        if extra:
            print(f"  [EXTRA KEYS]: {sorted(list(extra))}")
            errors += len(extra)

        # 2. Check for metadata alignment (@key for each key with placeholders)
        for key in template_keys:
            if key in data:
                val = data[key]
                has_placeholders = '{' in val
                meta_key = f"@{key}"
                
                if has_placeholders and meta_key not in data:
                    print(f"  [MISSING METADATA]: Key '{key}' has placeholders but no '{meta_key}'")
                    errors += 1
                elif meta_key in data:
                    # check placeholders
                    en_placeholders = set(re.findall(r'{(\w+)}', template_data.get(key, "")))
                    loc_placeholders = set(re.findall(r'{(\w+)}', val))
                    if en_placeholders != loc_placeholders:
                        print(f"  [PLACEHOLDER MISMATCH]: Key '{key}': Template={en_placeholders}, {filename}={loc_placeholders}")
                        errors += 1
                    
                    # check metadata placeholders
                    en_meta_p = set(template_data.get(meta_key, {}).get('placeholders', {}).keys())
                    loc_meta_p = set(data.get(meta_key, {}).get('placeholders', {}).keys())
                    if en_meta_p != loc_meta_p:
                        print(f"  [META PLACEHOLDER MISMATCH]: Metadata '{meta_key}': Template={en_meta_p}, {filename}={loc_meta_p}")
                        errors += 1

        # 3. Check for suspicious untranslated (identical to English)
        for key in template_keys:
            if key in data and key in template_data:
                if data[key] == template_data[key] and len(data[key]) > 20:
                    # Skip for IT where 'file' is common, etc.
                    if filename == 'app_it.arb' and 'file' in data[key].lower():
                        continue
                    print(f"  [SUSPECT UNTRANSLATED]: Key '{key}' matches English version exactly.")

        if errors == 0:
            print("  OK")
        total_errors += errors

    print(f"\nTotal errors found: {total_errors}")
    sys.exit(1 if total_errors > 0 else 0)

if __name__ == "__main__":
    check_translations()
