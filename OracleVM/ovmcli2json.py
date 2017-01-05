#!/usr/bin/python
#
# Date: 05.01.2017
#
# Copyright 2017 (c) Thorsten Bruhns (thorsten.bruhns@opitz-consutling.de)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# The code for converter from XML to json is from:
# https://github.com/lifebeyondfife/XMLtoJSON/blob/master/xml_to_json.py

import subprocess, sys, json

from lxml import objectify
from json import dumps

def _flatten_attributes(property_name, lookup, attributes):
    if attributes is None:
        return lookup

    if not isinstance(lookup, dict):
        return dict(attributes.items() + [(property_name, lookup)])

    return dict(lookup.items() + attributes.items())


def _xml_element_to_json(xml_element, attributes):
    if isinstance(xml_element, objectify.BoolElement):
        return _flatten_attributes(xml_element.tag, bool(xml_element), attributes)

    if isinstance(xml_element, objectify.IntElement):
        return _flatten_attributes(xml_element.tag, int(xml_element), attributes)

    if isinstance(xml_element, objectify.FloatElement):
        return _flatten_attributes(xml_element.tag, float(xml_element), attributes)

    if isinstance(xml_element, objectify.StringElement):
        return _flatten_attributes(xml_element.tag, str(xml_element).strip(), attributes)

    return _flatten_attributes(xml_element.tag, _xml_to_json(xml_element.getchildren()), attributes)


def _xml_to_json(xml_object):
    attributes = None
    if hasattr(xml_object, "attrib") and not xml_object.attrib == {}:
        attributes = xml_object.attrib

    if isinstance(xml_object, objectify.ObjectifiedElement):
        return _xml_element_to_json(xml_object, attributes)

    if isinstance(xml_object, list):
        if len(xml_object) > 1 and all(xml_object[0].tag == item.tag for item in xml_object):
            return [_xml_to_json(attr) for attr in xml_object]

        return dict([(item.tag, _xml_to_json(item)) for item in xml_object])

    return Exception("Not a valid lxml object")


def xml_to_json(xml):
    xml_object = xml if isinstance(xml, objectify.ObjectifiedElement) \
                     else objectify.fromstring(xml)
    return dumps({xml_object.tag: _xml_to_json(xml_object)})


if __name__ == "__main__":

    arguments = ' '.join(map(str, sys.argv[1:]))
    cmd=['ssh -p 10000 admin@localhost "set outputMode=Xml;%s"' % arguments]

    p = subprocess.Popen(args=cmd, shell=True, stdout=subprocess.PIPE)

    printblock = 0
    xmlresult = ''

    # we get 2 XML-Blocks as a result.
    # => Skip 1st block and print the 2nd

    for line in iter(p.stdout.readline, b''):

        if line[1:5] == 'OVM>':
            # remove the command output from OVMCLI
            printblock += 1
            continue

        if line[1:6] == '<?xml':
            # ignore the <?xml  line at the beginning of a block
            continue

        if printblock == 1:
            xmlresult += line


    jsonresult = xml_to_json(xmlresult)

    print jsonresult

