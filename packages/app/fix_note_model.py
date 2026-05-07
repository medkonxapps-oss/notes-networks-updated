import os

file_path = '../shared/lib/models/note.dart'
if os.path.exists(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    old_code = """      authorName: user?['full_name'] as String?,
      authorUsername: user?['username'] as String?,
      authorAvatarUrl: user?['avatar_url'] as String?,
      authorIsVerified: user?['is_verified_creator'] as bool? ?? false,"""
    
    new_code = """      authorName: (user?['full_name'] ?? j['full_name']) as String?,
      authorUsername: (user?['username'] ?? j['username']) as String?,
      authorAvatarUrl: (user?['avatar_url'] ?? j['avatar_url']) as String?,
      authorIsVerified: (user?['is_verified_creator'] ?? j['is_verified_creator'] ?? false) as bool,"""
    
    if old_code in content:
        new_content = content.replace(old_code, new_code)
        with open(file_path, 'w') as f:
            f.write(new_content)
        print("Successfully updated note.dart")
    else:
        # Try a slightly different version in case of formatting
        print("Old code not found in note.dart exactly, trying more flexible match")
        import re
        pattern = re.compile(r"authorName: user\?\['full_name'\] as String\?,\s+authorUsername: user\?\['username'\] as String\?,\s+authorAvatarUrl: user\?\['avatar_url'\] as String\?,\s+authorIsVerified: user\?\['is_verified_creator'\] as bool\?\s+\?\?\s+false,")
        if pattern.search(content):
            new_content = pattern.sub(new_code, content)
            with open(file_path, 'w') as f:
                f.write(new_content)
            print("Successfully updated note.dart using regex")
        else:
            print("Regex also failed")

else:
    print("File not found")
