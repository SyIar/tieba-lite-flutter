"""Generate native Swift protocols with the same pinned SwiftProtobuf runtime."""
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
output = root / 'native/Core/Generated'
output.mkdir(parents=True, exist_ok=True)
checkout = root / 'native/.build/checkouts/swift-protobuf'
subprocess.run(['swift', 'package', '--package-path', str(root / 'native'), 'resolve'], check=True)
subprocess.run(['swift', 'build', '--package-path', str(checkout), '-c', 'release', '--product', 'protoc-gen-swift'], check=True)
plugin = checkout / '.build/release/protoc-gen-swift'
files = sorted((root / 'proto').rglob('*.proto'))
subprocess.run(['protoc', f'--plugin=protoc-gen-swift={plugin}', '-I', str(root / 'proto'),
                f'--swift_out={output}', '--swift_opt=FileNaming=PathToUnderscores', '--swift_opt=UseAccessLevelOnImports=false',
                *map(str, files)], check=True)

# Read the generated declarations instead of assuming package-name casing.
types = {}
for path in output.glob('*.swift'):
    for match in re.finditer(r'^struct (\w+).*?\n', path.read_text(), re.M):
        types[match.group(1).split('_')[-1]] = match.group(1)
codecs = ['FrsPage', 'PbPage', 'PbFloor', 'Personalized', 'UserLike', 'HotThreadList', 'TopicList',
          'SearchSug', 'Profile', 'UserPost', 'GetForumDetail', 'ForumRuleDetail', 'AddPost']
lines = ['import Foundation', 'import SwiftProtobuf', '', 'enum ProtoCodec {',
         '  static func encode(_ name: String, json: Data) throws -> Data {', '    switch name {']
for codec in codecs:
    lines.append(f'    case "{codec}": return try {types[codec + "Request"]}(jsonUTF8Data: json).serializedData()')
lines += ['    default: throw APIError(message: "Unknown protocol request.")', '    }', '  }',
          '  static func decode(_ name: String, bytes: Data) throws -> JSON {', '    let data: Data', '    switch name {']
for codec in codecs:
    lines.append(f'    case "{codec}": data = try {types[codec + "Response"]}(serializedBytes: bytes).jsonUTF8Data()')
lines += ['    default: throw APIError(message: "Unknown protocol response.")', '    }',
          '    return (try JSONSerialization.jsonObject(with: data)) as? JSON ?? [:]', '  }', '}', '']
(root / 'native/Core/ProtoCodec.swift').write_text('\n'.join(lines))
print(f'Generated {len(files)} protocol files and {len(codecs)} request/response codecs')
