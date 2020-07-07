import argparse
import re
import subprocess
import sys
from tomlkit import parse as toml_load
from lxml.etree import CDATA, SubElement, ElementTree, Element

REPLACE_REGEX = re.compile(r'\$\{([\w\$]+)\}')

class UnknownVariable(Exception):
  pass



def get(base, path, default=None, req=True, prefix=None):
  """
  Helper method to get a nested field from dict tree.
  :param base: Base of the tree
  :param path: "." separated keys
  """
  if default is not None:
    req = False
  o = base
  p = path.split('.')
  ok = True
  for k in p:
    # Handle arrays
    if isinstance(o, list):
      ki = int(k)
      if ki < len(o):
        o = o[ki]
      else:
        o = None
    # Default case is dict
    else:
      o = o.get(k)
    # Error out
    if o is None:
      if req:
        err_path = '.'.join([] + (prefix or []) + p)
        raise Exception("Failed to find %s" % (err_path))
      else:
        return default
  return o

def replace_text(s, vars, path):
  """
  Do variable expansion for the string \c s 
  """
  vars['$'] = '$' # I shouldn't really modify the dict I'm receiving, but it doesn't matter
  o = '' # Output string we're building
  parts = re.split(REPLACE_REGEX, s) # Every odd-numbered string is a variable name
  # Iterate through all parts
  for i in range(0, len(parts)):
    # Even indexes were not matched
    if i % 2 == 0:
      o += parts[i]
    # Odd indexes are variables
    else:
      var = parts[i]
      if var in vars:
        o += vars[var]
      else:
        raise UnknownVariable('Unknown variable "%s" in %s' % (var, '.'.join(path)))
  return o

class Converter:
  def __init__(self, data, use_pandoc=True, pandoc_path='pandoc'):
    self.data = data
    self.use_pandoc = use_pandoc
    self.pandoc_path = pandoc_path

  def convert(self):
    data = self.data
    # Root XML element
    root = Element('index', {
      'version': str(get(data, 'index.version')),
      'name': get(data, 'index.name'),
    })
    
    # dict of category names -> list of <reapack> Elements
    categories = {}
    
    for key,pack in get(data, 'reapack').items():
      path = ['reapack', key]
      xmlpack = Element('reapack', {
        'name': get(pack, 'name', prefix=path),
        'type': get(pack, 'type', prefix=path),
      })
      category = get(pack, 'category', prefix=path)
      # Parse the metadata fields
      meta_t = get(pack, 'metadata', req=False, prefix=path)
      if meta_t is not None:
        xmlpack.append(process_metadata(meta_t, path))
      
      # Parse versions
      for key2,version in get(pack, 'version', prefix=path).items():
        path2 = path + ['version', '"%s"'%key2]
        xmlpack.append(process_version(version, key2, path2, pack.get('author')))
      
      # Stick this pack in the correct category list
      if category not in categories:
        categories[category] = []
      categories[category].append(xmlpack)
    
    # We've processed all the packs, so reorganize the XML appropriately
    for k,v in categories.items():
      SubElement(root, 'category', { 'name': k }).extend(v)

    return root

def process_version(version, key, path, author):
  cpath = path
  vars = (version.get('vars') or {})
  xmlver = Element('version', {
    'name': key,
    'author': version.get('author') or author,
    'time': get(version, 'time', prefix=path),
  })
  SubElement(xmlver, 'changelog').text = CDATA(get(version, 'changelog', path))
  file_list = get(version, 'files', path)
  for i in range(len(file_list)):
    filedef = file_list[i]
    cpath = path + ['files', str(i + 1)]
    if isinstance(filedef, str):
      # Simple case: just a string
      SubElement(xmlver, 'source').text = replace_text(filedef, vars, cpath)
    else:
      # Complex case, dictionary with fields
      # TODO process variables
      attribs = filedef.copy()
      for k,v in attribs.items():
        attribs[k] = replace_text(str(v), vars, cpath)
      src = attribs.pop('src')
      SubElement(xmlver, 'source', attribs).text = src
  return xmlver
# end process_version

def process_metadata(meta_t, path):
  meta_x = Element('metadata')
  
  # These are standard link types
  LINK_TYPES = ['website', 'donation']
  for lt in LINK_TYPES:        
    tmp = meta_t.get(lt)
    if tmp:
      SubElement(meta_x, 'link', { 'rel': lt }).text = tmp
  
  # Screenshots is an array
  screenshots = (meta_t.get('screenshots') or [])
  for i in range(len(screenshots)):
    path2 = path + ['metadata', 'screenshots', i]
    href = get(screenshots[i], 'href', prefix=path2)
    el = SubElement(meta_x, 'link', { 'rel': 'screenshot', 'href': href })
    el.text = get(screenshots[i], 'text', req=False, default=href)
  
  # if there's a description field, use pandoc to convert it to rtf
  desc = meta_t.get('description')
  if desc:
    proc = subprocess.run(['pandoc', '-f', 'markdown', '-t', 'rtf'], 
      input=desc, capture_output=True, text=True)
    SubElement(meta_x, 'description').text = proc.stdout
  
  return meta_x
# end process_metadata

def main(argv):
  parser = argparse.ArgumentParser()
  parser.add_argument('file', type=str,
    help='The input toml file to process')
  parser.add_argument('-o', '--output', type=str, default='index.xml',
    help='Output XML file (default: index.xml)')
  args = parser.parse_args(argv)

  # Load our input file
  with open(args.file, "r") as fd:
    data = toml_load(fd.read())
  conv = Converter(data)
  with open(args.output, "wb") as fd:
    ElementTree(conv.convert()).write(fd, encoding='utf-8', pretty_print=True)
  

if __name__ == '__main__':
  main(sys.argv[1:])