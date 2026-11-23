"""Link split compiler inputs and inspect the resulting Objective-C registrations."""
from pathlib import Path
import subprocess
import tempfile
import unittest

from check_editable_admob import RuntimeMetadata
from editable_objc import merge_objc_assembly


ROOT = Path(__file__).resolve().parents[1]
CLANG = ROOT / '.toolchains/apple502/bin/clang'
SDK = ROOT / '.toolchains/iPhoneOS7.0.sdk'
INTERFACE = """
#import <Foundation/NSObject.h>
@protocol GADFixtureProtocol
- (int)value;
@end
@interface GADFixture : NSObject <GADFixtureProtocol> {
    int _padding;
    int _value;
}
@property(nonatomic) int value;
@end
"""
RUNTIME = INTERFACE + """
@implementation GADFixture
@synthesize value = _value;
@end
int main(void) { return 0; }
"""
FIRST = INTERFACE + """
static volatile int local = 6;
@implementation GADFixture
@dynamic value;
+ (void)load { local++; }
- (int)value { return local; }
@end
@interface NSObject (GADFixtureCategory)
- (int)categoryValue;
@end
@implementation NSObject (GADFixtureCategory)
- (int)categoryValue { return local; }
@end
"""
SECOND = INTERFACE + """
static volatile int local = 7;
@implementation GADFixture
@dynamic value;
- (int)value { return _value + local; }
- (int)addedValue { return _value; }
@end
"""


@unittest.skipUnless(CLANG.is_file() and (SDK / 'usr/lib/libSystem.dylib').is_file(),
                     'requires the editable iOS toolchain')
class EditableObjCTests(unittest.TestCase):
    def test_split_classes_link_with_selected_imps_and_runtime_ivar_cells(self):
        for arch in ('armv7', 'armv7s'):
            with self.subTest(arch=arch), tempfile.TemporaryDirectory() as raw:
                directory = Path(raw)
                common = [CLANG, '-target', arch + '-apple-ios6.0', '-isysroot', SDK,
                          '-integrated-as', '-Os']
                assemblies = {}
                for stem, source, mode in [('runtime', RUNTIME, '-mthumb'),
                                           ('first', FIRST, '-mthumb'),
                                           ('second', SECOND, '-marm')]:
                    path = directory / (stem + '.m')
                    assembly = path.with_suffix('.s')
                    path.write_text(source)
                    subprocess.run([*common, mode, '-S', path, '-o', assembly], check=True)
                    assemblies[path] = assembly
                runtime = assemblies.pop(directory / 'runtime.m')
                with self.assertRaisesRegex(ValueError, 'ambiguous method'):
                    merge_objc_assembly(runtime, assemblies, {})
                merge_objc_assembly(runtime, assemblies, {'-[GADFixture value]': directory / 'second.m'})
                obj = directory / 'combined.o'
                exe = directory / 'combined'
                subprocess.run([*common, '-x', 'assembler', '-c', runtime, '-o', obj], check=True)
                subprocess.run(['xcrun', 'ld', '-arch', arch, '-ios_version_min', '6.0', '-syslibroot',
                                SDK, '-o', exe, obj, '-lSystem', '-lobjc', '-framework', 'Foundation'],
                               check=True, capture_output=True)
                metadata = RuntimeMetadata(exe.read_bytes())
                fixture = metadata.classes['GADFixture']
                self.assertEqual(set(fixture.methods), {
                    ('+', 'load'), ('-', 'value'), ('-', 'setValue:'), ('-', 'addedValue')})
                self.assertEqual(metadata.eager_classes, {'GADFixture'})
                self.assertEqual(fixture.protocols, {'GADFixtureProtocol'})
                self.assertEqual(fixture.ivars['_value'].offset, 8)
                self.assertEqual(fixture.properties['value'], 'Ti,N,V_value')
                self.assertEqual(fixture.methods['-', 'value'].imp & 1, 0)  # selected ARM body
                self.assertEqual(fixture.methods['+', 'load'].imp & 1, 1)   # other TU's Thumb body
                self.assertIn(('-', 'categoryValue'), metadata.categories['NSObject', 'GADFixtureCategory'].methods)


if __name__ == '__main__':
    unittest.main()
