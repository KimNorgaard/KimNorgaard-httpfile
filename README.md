puppet-httpfile
===============

Transfer files via HTTP(S)

Usage
-----

```
    httpfile { '/path/to/file.ext':
      path                      => '/path/to/file.ext',
      source                    => 'http://example.com/my_file.bin',
      force                     => false,
      checksum_type             => 'content_md5',
      expected_checksum         => 'b96af7576939a17ac4b2d4b6edb50ce7',
      print_progress            => true,
      http_open_timeout         => 5,
      http_verb                 => post,
      http_user                 => 'foo',
      http_pass                 => 'bar',
      http_request_content_type => 'application/json',
      http_request_headers      => {
        'X-Foo' => 'bar',
      },
      http_request_body         => '{ "file_name": "my_file.bin" }',
      http_post_form_data       => {
        'file_id' => 42,
      }
    }
```
