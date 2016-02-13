#!/bin/bash

rvm 1.9.3,2.2.1 do bundle exec ruby test/test_google_drive.rb
rvm 1.9.3,2.2.1 do bundle exec ruby test/test_google_drive_mocked.rb
