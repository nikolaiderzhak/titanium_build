#!/usr/bin/python
import os, re, socket, sys, utils
from boto.s3.connection import S3Connection
from boto.s3.key import Key
import zipfile
import simplejson

bucket = None

def read_properties(properties, separator=":= "):
	prop_dict = dict()
	for prop_line in properties.splitlines():
		prop_def = prop_line.strip()
		if len(prop_def) == 0:
			continue
		if prop_def[0] in ('!', '#'):
			continue

		punctuation = [prop_def.find(c) for c in separator] + [len(prop_def)]
		found = min([pos for pos in punctuation if pos != -1])

		name = prop_def[:found].rstrip()
		value = prop_def[found:].lstrip(separator).rstrip()
		prop_dict[name] = value

	return prop_dict

def upload_release(version, mobilesdk_zips):
	release_index = []

	for mobilesdk_zip in mobilesdk_zips:
		upload_mobilesdk(mobilesdk_zip)

		sdk_name = os.path.basename(mobilesdk_zip)
		matches = re.match(r"mobilesdk-([^-]+)-([^\.]+).zip", sdk_name)
		sdk_version = matches.group(1)
		sdk_os = matches.group(2)

		zip_data = zipfile.ZipFile(mobilesdk_zip)
		sdk_data = read_properties(zip_data.read("mobilesdk/%s/%s/version.txt" % (sdk_os, sdk_version)))
		zip_data.close()

		sha1 = utils.shasum(mobilesdk_zip)
		filesize = os.path.getsize(mobilesdk_zip)
		sdk_data["sha1"] = sha1
		sdk_data["filesize"] = filesize
		release_index.append(sdk_data)

def upload_mobilesdk(mobilesdk_zip):
	filename = os.path.basename(mobilesdk_zip)

	print 'uploading %s (version %s)...' % (filename, version)
	key = Key(bucket)
	key.key = 'release/%s/%s' % (version, filename)

	max_retries = 5
	uploaded = False
	for i in range(1, max_retries+1):
		try:
			key.set_contents_from_filename(path)
			print "-> succesfully uploaded on attempt #%d" % i
			uploaded = True
			break
		except socket.error, e:
			if i <= max_retries:
				print '-> received error: %s, retrying upload (attempt #%d)...' % (str(e), i+1)

	if not uploaded:
		print >>sys.stderr, "Failed to upload %s after %d attempts" % (path, max_retries)
		sys.exit(1)

	key.make_public()

def update_release_json(version, release_index):
	print 'updating release/index.json..'
	index_key = bucket.get_key('release/index.json')
	index = []
	if index_key == None:
		index_key = Key(bucket)
		index_key.key = 'release/index.json'
	else:
		index = simplejson.loads(index_key.get_contents_as_string())

	if version not in index:
		index.append(version)
		index_key.set_contents_from_string(simplejson.dumps(index))
		index_key.make_public()

	release_key = bucket.get_key('release/%s/index.json' % version)
	if release_key == None:
		release_key = Key(bucket)
		release_key.key = 'release/%s/index.json' % version

	release_key.set_contents_from_string(simplejson.dumps(release_index))
	release_key.make_public()

def main():
	if len(sys.argv) < 3:
		print "Usage: %s <version> [mobilesdk-XXX.zip, ..]" % sys.argv[0]
		sys.exit(1)

	version = sys.argv[1]
	mobilesdk_zips = sys.argv[2:]

	cfg = utils.get_build_config()
	if not cfg.verify_aws():
		print "Error: Need both AWS_KEY and AWS_SECRET in the environment or config.json"
		sys.exit(1)

	global bucket
	bucket = cfg.open_bucket()
	upload_release(version, mobilesdk_zips)
