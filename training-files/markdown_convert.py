import os

def convert_move_to_md(move_file_path, md_file_path):
    try:
        with open(move_file_path, 'r') as move_file:
            code = move_file.read()

        # Check for duplicate filenames and add a counter if needed
        counter = 1
        original_md_file_path = md_file_path
        while os.path.exists(md_file_path):
            md_file_path = original_md_file_path.replace('.md', f'_{counter}.md')
            counter += 1

        with open(md_file_path, 'w') as md_file:
            md_file.write("```rust\n" + code + "\n```")
        print(f"Converted {move_file_path} to {md_file_path}")
    except Exception as e:
        print(f"Error processing {move_file_path}: {e}")

def process_directory(directory):
    move_folder = os.path.join(directory, 'move')
    md_move_folder = os.path.join(directory, 'md-move')

    # Check if the move/ folder exists
    if not os.path.exists(move_folder):
        print(f"Skipping {directory}: move/ folder not found")
        return

    # Create the md-move/ folder if it doesn't exist
    os.makedirs(md_move_folder, exist_ok=True)

    for root, dirs, files in os.walk(move_folder):
        for file in files:
            if file.endswith('.move'):
                move_file_path = os.path.join(root, file)
                md_file_path = os.path.join(md_move_folder, file.replace('.move', '.md'))
                convert_move_to_md(move_file_path, md_file_path)

# Start from the dapps/ directory
start_directory = 'dapps'
for subdir in os.listdir(start_directory):
    if os.path.isdir(os.path.join(start_directory, subdir)):
        process_directory(os.path.join(start_directory, subdir))

