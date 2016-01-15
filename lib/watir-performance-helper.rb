#!/usr/bin/ruby

require 'watir-webdriver'
require 'watir-webdriver-performance'

require 'benchmark'

module Watir

  class Browser
    alias_method(:orig_goto, :goto) unless method_defined?(:orig_goto)
    alias_method(:orig_initialize, :initialize)

    attr_accessor :transaction_name
    attr_accessor :re_last
    attr_accessor :rt_last
    
    @transaction_name
    @re_last
    @rt_last

    def initialize(browser = :firefox, *args)
        self.transaction_name = ''
        self.re_last = 0
        orig_initialize browser, args
    end
  
    def run_performance_checks()
      puts "run_performance_checks start"

      re = self.performance.timing[:response_end]
      if ((re - self.re_last) > 0)
        ctm = ''
        self.re_last = re
        rt = browser.performance.summary[:response_time]/1000.0

        if browser.transaction_name == ''
          # XXX. WARN. you should specify a transaction_name
          ctm = browser.url + browser.window.title
          ctm = ctm.gsub(/[^\w-]/, "_")
        else
          ctm = browser.transaction_name
        end

        # TODO. FIXME. globals
        if $ctms
          $ctms[ctm] = rt
          puts $ctms
        end

        puts "#{rt}|#{ctm}|#{browser.performance.summary}"
        # puts "#{rt}|#{ctm}|#{browser.performance.summary}|#{browser.performance.timing}"

        self.rt_last = rt
        
        # reset
        if not browser.transaction_name == ''
          browser.transaction_name = ''
        end

      else
        STDERR.puts "WARN: zero delta response end"
      end
      puts "run_performance_checks end"
    end
  
    def goto(uri)
      uri = "http://#{uri}" unless uri.include?("://")
    
      @driver.navigate.to uri
      run_checkers

      browser.run_performance_checks

      url
    end
  end

  class Element
    alias_method(:orig_click, :click) unless method_defined?(:orig_click)

    def click(*modifiers)

      # parent.parent.flash
      # parent.flash
      # flash
      
      self.focus
      rv = orig_click(*modifiers)

      browser.run_performance_checks

      rv
    end
  end

  class Radio
    alias_method(:orig_set, :set) unless method_defined?(:orig_set)

    def set(*modifiers)
      self.focus
      rv = orig_set(*modifiers)
      rv
    end
  end

  class CheckBox
    alias_method(:orig_set, :set) unless method_defined?(:orig_set)

    def set(*modifiers)
      self.focus
      rv = orig_set(*modifiers)
      rv
    end
  end

  class FileField
    alias_method(:orig_set, :set) unless method_defined?(:orig_set)

    def set(*modifiers)
      self.focus
      rv = orig_set(*modifiers)
      rv
    end
  end

  module UserEditable
    alias_method(:orig_set, :set) unless method_defined?(:orig_set)

    def set(*modifiers)
      self.focus
      rv = orig_set(*modifiers)
      rv
    end
  end

  module Wait
    class << self
      alias_method(:orig_until, :until) unless method_defined?(:orig_until)

      def until(*modifiers, &block)

    # brt = Benchmark.realtime do
    #   @browser.transaction_name = '002_Login_Click'
    #   @browser.button(:class => 'login-button').click
    # end
    # puts "#{brt}|004_Login_Click"

        puts "start wait until"
        puts "#{modifiers} #{block}"
        rv = orig_until(*modifiers, &block)
        puts "end wait until"

        rv
      end
    end
  end
end

