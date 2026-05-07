import os

file_path = '../shared/lib/services/auth_service.dart'
if os.path.exists(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    old_code = """    final signed = await _client.storage
        .from('avatars')
        .createSignedUrl(key, 3600);
    await _client.from('users')
        .update({'avatar_url': signed}).eq('id', userId);
    return signed;"""
    
    new_code = """    final url = _client.storage.from('avatars').getPublicUrl(key);
    await _client.from('users')
        .update({'avatar_url': url}).eq('id', userId);
    return url;"""
    
    if old_code in content:
        new_content = content.replace(old_code, new_code)
        with open(file_path, 'w') as f:
            f.write(new_content)
        print("Successfully updated AuthService.dart")
    else:
        print("Old code not found in AuthService.dart")
else:
    print("File not found")
