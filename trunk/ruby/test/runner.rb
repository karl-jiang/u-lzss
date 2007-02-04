#!/usr/bin/env ruby

require 'test/unit/ui/console/testrunner'
require 'test/unit/testsuite'
require 'find'

dir = File.expand_path(File.dirname($0))
$LOAD_PATH.unshift dir
$LOAD_PATH.unshift File.join(dir, 'lib')
$LOAD_PATH.unshift File.join(dir, '../lib')

Find.find(dir) do |f|
  require f if f =~ /test_.*rb$/
end

class TS_AllTests
  def self.suite
    suite = Test::Unit::TestSuite.new
    suite << TC_LZSS.suite
  end
end
Test::Unit::UI::Console::TestRunner.run(TS_AllTests)


