import re

with open('lib/ui/listen_repeat/listen_repeat_view_model.dart', 'r') as f:
    content = f.read()

# Pattern for basic print statements
# print('...'); -> AppLogger.log('...', name: 'ListenRepeat');
content = re.sub(r"print\('([^']+)'\);", r"AppLogger.log('\1', name: 'ListenRepeat');", content)

# There's a couple of special cases with error stacks
content = content.replace("      print('[LR] ERROR: $e');\n      print('[LR] stack: $st');", "      AppLogger.error('Failed to start session', name: 'ListenRepeat', error: e, stackTrace: st);")
content = content.replace("      print('[LR-gen] ERROR: $e');\n      print('[LR-gen] stack: $st');\n      AppLogger.error('Error in _generateNextWordSequence', name: 'ListenRepeat', error: e);", "      AppLogger.error('Error in _generateNextWordSequence', name: 'ListenRepeat', error: e, stackTrace: st);")

# Update file
with open('lib/ui/listen_repeat/listen_repeat_view_model.dart', 'w') as f:
    f.write(content)
