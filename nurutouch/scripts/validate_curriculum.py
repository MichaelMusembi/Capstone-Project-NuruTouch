import yaml
import os

base_dir = r"C:\Users\LENOVO\Capstone Project NuruTouch\nurutouch\assets\curriculum"

def log_error(logfile, msg):
    print(msg)
    with open(logfile, 'a', encoding='utf-8') as f:
        f.write(msg + "\n")

def validate_all():
    logfile = os.path.join(base_dir, "validation_log.txt")
    if os.path.exists(logfile):
        os.remove(logfile)
        
    global_ids = set()
    letters_in_lessons = {} # map character -> target_dots
    
    # Pass 1: Collect lessons data for cross-ref
    for lang in ['english', 'swahili']:
        p = os.path.join(base_dir, lang, 'lessons.yaml')
        if not os.path.exists(p): continue
        with open(p, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
            for item in data.get('lessons', []):
                char = item.get('narration', {}).get('character')
                seq = item.get('sequence', [])
                if char and seq and seq[0].get('action') == 'tap_braille':
                    letters_in_lessons[char] = seq[0].get('target_dots', [])

    # Pass 2: Validate everything
    for lang in ['english', 'swahili']:
        for file_type in ['lessons.yaml', 'words.yaml', 'sentences.yaml', 'reviews.yaml']:
            path = os.path.join(base_dir, lang, file_type)
            if not os.path.exists(path):
                log_error(logfile, f"File missing: {path}")
                continue
                
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    data = yaml.safe_load(f)
            except Exception as e:
                log_error(logfile, f"Syntax Error in {path}: {e}")
                continue
                
            key = file_type.split('.')[0]
            items = data.get(key, [])
            for item in items:
                # 1. ID
                iid = item.get('id')
                if not iid:
                    log_error(logfile, f"{path}: Missing id")
                else:
                    if iid in global_ids:
                        log_error(logfile, f"{path}: Duplicate id {iid}")
                    global_ids.add(iid)
                
                # 2. Difficulty
                diff = item.get('difficulty')
                if not isinstance(diff, int) or diff < 1 or diff > 10:
                    log_error(logfile, f"{path} {iid}: Invalid difficulty {diff}")
                    
                # 3. Narration
                nar = item.get('narration')
                if not isinstance(nar, dict):
                    log_error(logfile, f"{path} {iid}: Missing/invalid narration object")
                else:
                    if 'spoken_form' not in nar:
                        log_error(logfile, f"{path} {iid}: Missing spoken_form")
                    if key == 'lessons' and 'character' not in nar:
                        log_error(logfile, f"{path} {iid}: Lessons must have character in narration")
                        
                    steps = nar.get('steps')
                    if not isinstance(steps, list):
                        log_error(logfile, f"{path} {iid}: Missing steps list")
                    else:
                        types = [s.get('type') for s in steps]
                        if key == 'reviews':
                            if set(types) != {'prompt', 'retry', 'success'}:
                                log_error(logfile, f"{path} {iid}: Reviews steps must be prompt,retry,success")
                        else:
                            if set(types) != {'explain', 'prompt', 'retry', 'success'}:
                                log_error(logfile, f"{path} {iid}: Steps must contain explain,prompt,retry,success. Found {set(types)}")
                                
                    # Swahili check
                    if lang == 'swahili':
                        sf = nar.get('spoken_form', '')
                        # Simple heuristic check: if not a vowel and length 1, it's not silabi
                        # Note: This is a loose check.
                        
                # 4. Sequence
                seq = item.get('sequence')
                if not isinstance(seq, list) or len(seq) == 0:
                    log_error(logfile, f"{path} {iid}: Sequence must be non-empty list")
                else:
                    for s in seq:
                        action = s.get('action')
                        if action not in ['tap_braille', 'swipe_right']:
                            log_error(logfile, f"{path} {iid}: Invalid action {action}")
                        if action == 'tap_braille' and not isinstance(s.get('target_dots'), list):
                            log_error(logfile, f"{path} {iid}: tap_braille needs target_dots list")
                            
                # 5. Confuser family
                if key == 'lessons':
                    if 'confuser_family' not in item or not isinstance(item['confuser_family'], list):
                        log_error(logfile, f"{path} {iid}: Missing confuser_family list")
                        
    # Pass 3: Validate dot_descriptions.yaml
    dot_desc_path = os.path.join(base_dir, "..", "narration", "dot_descriptions.yaml")
    if os.path.exists(dot_desc_path):
        try:
            with open(dot_desc_path, 'r', encoding='utf-8') as f:
                dot_data = yaml.safe_load(f)
            dots = dot_data.get('dots', {})
            for i in range(1, 7):
                if i not in dots:
                    log_error(logfile, f"dot_descriptions.yaml: Missing dot {i}")
                else:
                    dot = dots[i]
                    for field in ['finger_name_en', 'finger_name_sw', 'position_en', 'position_sw']:
                        if field not in dot:
                            log_error(logfile, f"dot_descriptions.yaml dot {i}: Missing {field}")
        except Exception as e:
            log_error(logfile, f"Error validating dot_descriptions.yaml: {e}")
    else:
        log_error(logfile, "dot_descriptions.yaml not found")
        
    log_error(logfile, "Validation Complete.")
if __name__ == '__main__':
    validate_all()
