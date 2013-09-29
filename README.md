puppet-httpfile
===============

Transfer files via HTTP(S)

Basic Usage
-----------

```
    httpfile { '/path/to/file.ext':
      path                      => '/path/to/file.ext',
      source                    => 'http://example.com/my_file.bin',
      http_user                 => 'foo',
      http_pass                 => 'bar',
    }
```
