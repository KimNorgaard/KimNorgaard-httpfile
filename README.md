KimNorgaard-httpfile
====================

Transfer files via HTTP(S).

Uses various methods to verify the checksum before actually fetching the file.

Basic Usage
-----------
```
    httpfile { '/path/to/file.ext':
      path                      => '/path/to/file.ext',
      source                    => 'http://example.com/my_file.bin',
    }
```

By default, the Content-MD5 header is used to compare checksums. For apache,
this can be achieved by setting the 'ContentDigest' directive to 'On'.

If you prefer to use sidecar files (i.e. .md5 or .sha1) placed on the server,
you can do that by setting the checksum_type parameter.
