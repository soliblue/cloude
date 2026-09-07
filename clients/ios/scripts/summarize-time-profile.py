import collections
import json
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
references = {element.attrib['id']: element for element in root.iter() if 'id' in element.attrib}

def resolved(element):
    return references[element.attrib['ref']] if 'ref' in element.attrib else element

threads = collections.Counter()
leaves = collections.Counter()
app_stacks = collections.Counter()
main_leaves = collections.Counter()
unknown_app_frames = set()
rows = root.findall('.//row')
for row in rows:
    thread = resolved(row.find('thread')).attrib.get('fmt', '')
    weight = int(resolved(row.find('weight')).text) / 1_000_000
    threads[thread] += weight
    frames = [resolved(frame) for frame in resolved(row.find('backtrace')).findall('frame')]
    if frames:
        leaves[frames[0].attrib.get('name', '')] += weight
        if thread.startswith('Main Thread'):
            main_leaves[frames[0].attrib.get('name', '')] += weight
    seen = set()
    for frame in frames:
        binary = frame.find('binary')
        if binary is not None and resolved(binary).attrib.get('name') in ('Cloude', 'Cloude.debug.dylib'):
            name = frame.attrib.get('name', '')
            if name.startswith('0x'):
                unknown_app_frames.add(name)
            if name not in seen:
                app_stacks[name] += weight
                seen.add(name)
summary = {
    'sample_rows': len(rows),
    'sampled_cpu_ms': sum(threads.values()),
    'threads_ms': threads.most_common(),
    'top_leaves_ms': leaves.most_common(20),
    'top_main_leaves_ms': main_leaves.most_common(20),
    'top_app_inclusive_ms': app_stacks.most_common(40),
    'unsymbolicated_app_frames': sorted(unknown_app_frames),
}
print(json.dumps(summary, indent=2))
