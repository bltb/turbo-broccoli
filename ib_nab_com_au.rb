#!/usr/bin/ruby
# -*- coding: utf-8 -*-

$LOAD_PATH << File.expand_path(File.dirname(__FILE__) + '/lib')

require 'irb/completion'
require 'irb/ext/save-history'
require 'watir-webdriver'
require 'selenium-webdriver'
require 'watir-webdriver-performance'
require 'benchmark'
require 'json'
require 'csv'

require 'yaml'

# require 'watir-performance-helper'

STDOUT.sync = true

APPLICATION = 'ib.nab.com.au'
CONFIG_FILE = 'config.yaml'
ERROR_SCREENSHOT_FILE = "#{APPLICATION}_error_screenshot.png"

if File.exist?(ERROR_SCREENSHOT_FILE)
  puts "ERROR: file exists [#{ERROR_SCREENSHOT_FILE}]"
  exit 1
end

config = YAML.load_file(CONFIG_FILE)
config[APPLICATION].each do |key, value|
  instance_variable_set("@#{key}", value)
end

USERNAME = config[APPLICATION]['username']
PASSWORD = config[APPLICATION]['password']

DRIVER = :chrome
# DRIVER = :firefox

download_directory = "#{Dir.pwd}/downloads/#{Process.pid}"

client = Selenium::WebDriver::Remote::Http::Default.new
client.timeout = 300 # seconds - default is 60

if DRIVER == :chrome
  #   profile = Selenium::WebDriver::Firefox::Profile.new
  #   profile['download.prompt_for_download'] = false
  #   profile['download.default_directory'] = download_directory
  switches = ['--proxy-server=localhost:9099']
  # switches = ''

  driver = Selenium::WebDriver.for(
    :chrome,
    #  :profile => profile,
    http_client: client,
    switches: switches
  # switches: %w[--ignore-certificate-errors
  # --disable-popup-blocking --disable-translate]
  )

else

  profile = Selenium::WebDriver::Firefox::Profile.new

=begin
#  # N.B. this Firefox profile must be created first
profile = Selenium::WebDriver::Firefox::Profile.new (
    './sgvorxky.webdriver.download.002')
profile = Selenium::WebDriver::Firefox::Profile.new (
    '/home/blt/.mozilla/firefox/cifxzbwy.webdriver')
=end
  profile['browser.download.folderList'] = 2    # custom location
  profile['browser.download.useDownloadDir'] = true
  profile['browser.download.dir'] = download_directory
  # XXX.
  driver = Selenium::WebDriver.for(
    :firefox,
    profile: profile,
    http_client: client
  )
end

@browser = Watir::Browser.new(driver)

@browser.window.resize_to(1200, 1600)
@browser.window.move_to(0, 0)
@browser.transaction_name = '000_Calculate_Round_Trip_Time'
@browser.goto 'http://www.google.com.au/gen_204'

puts @browser.rt_last.to_s + '|000_Calculate_Round_Trip_Time'

@browser.transaction_name = '00l_Home_Goto'
@browser.goto 'https://ib.nab.com.au/nabib/index.jsp'

@browser.text_field(name: 'userid').set USERNAME
@browser.text_field(name: 'password').set PASSWORD

begin

  brt = Benchmark.realtime do
    @browser.transaction_name = '002_Login_Click'
    @browser.a(class: 'link-btn link-btn_lg black').click
  end
  puts "#{brt}|004_Login_Click"

  # all errors

  if @browser.p(id: 'errorMessage').present?
    em = @browser.p(id: 'errorMessage').text

    en = @browser.span(id: 'errorNumber').text
    en = en.gsub(/[^0-9]/, '')

    p "errorMessage = #{em}"
    p "errorNumber = #{en}"

    em_ = em.gsub(/\\n/, '_')
    em_ = em_.gsub(/[^A-Za-z]/, '_')
    p em_

    case en
    when '200020',   # /Internet Banking is temporarily unavailable/
         '400012',   # /Service temporarily unavailable/
         '201015',   # /Your Internet Banking session has timed out due to inactivity/
         '210006'    # /Back-End System is unavailable/
      puts @browser.rt_last.to_s + "|002_Login_Error_#{em_}"
      exit 2
    else
      puts 'Unknown error'
    end

  end

  # Sometimes a post login page is displayed (in an iframe, I think)
  @browser.iframes.collect do |i|
    p 'begin collect iframes'
    p i.src
    p i.id
    p i.name
    if i.src =~ /.*static.*postLogin.*/
      p 'found = static post login iframe'
      i.a(title: 'Continue to Internet Banking').click
    end
    p 'end collect iframes'
  end


  # @browser.a(:title => "Bill payment").wait_until_present
  #
  # sleep(120)
  
  p 'begin is present = Transaction history'
  @browser.a(text: 'Transaction history').wait_until_present
  p 'end is present = Transaction history'

  
 
  FUNDS_TRANSFER_ENABLED = true

  if FUNDS_TRANSFER_ENABLED
  
    @browser.goto 'https://ib.nab.com.au/nabib/payments_transferNew.ctl'

    account_from = config[APPLICATION]['session']['account_from']
    account_to = config[APPLICATION]['session']['account_to']

    # swap
    p 'Swap accounts'
    config[APPLICATION]['session']['account_from'] = account_to
    config[APPLICATION]['session']['account_to'] = account_from

    p 'Write YAML'
    File.open(CONFIG_FILE + '.new', 'w') do |f|
      f.write config.to_yaml
    end
    
    @browser.select_list(id: 'fromAccount').select_value account_from
    @browser.select_list(id: 'toAccount').select_value account_to

    @browser.select_list(id: 'fromAccount').options.collect do |o|
      puts o.value
      puts o.text
    end

    amount = '1'
    description = 'uno.' + `date +%s`.strip + '.' +
                  `uuidgen | sha512sum | cut -c1-2`.strip

    remitter_name = `echo "#{description}" | sha512sum | cut -c1-18`.strip

    @browser.text_field(id: 'amount').set amount
    @browser.text_field(id: 'description').set description
    @browser.text_field(id: 'remitterName').set remitter_name

    # XXX. sometimes the nextButton is present and sometimes not
    if @browser.button(id: 'nextButton').exists?
      @browser.button(id: 'nextButton').click
    end

    @browser.button(id: 'submitTransfer').click

    puts ['CSV', account_from, account_to, amount, description, remitter_name]
      .reject(&:empty?)
      .join(',')

    p 'Rename YAML'
    File.rename(CONFIG_FILE + '.new', CONFIG_FILE)

    p 'begin is present = Accounts'
    @browser.a(text: 'Accounts').wait_until_present
    p 'end is present = Accounts'

    @browser.goto 'https://ib.nab.com.au/nabib/acctInfo_acctBal.ctl'

    p 'begin is present = Transaction history'
    @browser.a(text: 'Transaction history').wait_until_present
    p 'end is present = Transaction history'
    brt = Benchmark.realtime do
      # FIXME. seems that I have been timing / naming
      # Bill Payment as Transaction History
      @browser.transaction_name = '100_Bill_Payment_Click'
      @browser.a(text: 'Transaction history').click
      # @browser.a(:title => 'Bill payment').click
    end
    puts "#{brt}|101_Bill_Payment_Click"




    begin
      td = @browser.td(xpath: '//tr[@id="someItemsRow"]/td[1]')
      puts td.text
      puts "Total transactions: #{td.text}"
    rescue Watir::Exception::UnknownObjectException => e
      puts e
      Watir::Wait.until do
        @browser.alert.exists?
      end
      puts @browser.alert.text
      @browser.alert.ok
    end



  end



  brt = Benchmark.realtime do
    @browser.transaction_name = '200_Account_Summary_Click'
    @browser.a(text: 'Account summary').click
  end
  puts "#{brt}|201_Account_Summary_Click"

  brt = Benchmark.realtime do
    @browser.transaction_name = '900_Logout_Click'

    begin
      # http://watirwebdriver.com/javascript-dialogs/
      #
      # don't return anything for alert
      @browser.execute_script('window.alert = function() {}')
      #
      @browser.a(id: 'logoutButton').click
      #
      # XXX. ERROR: unreachable unless we handle the alert dialog
      # exception seems to be thrown here by the helper class
      #
    rescue Selenium::WebDriver::Error::UnhandledAlertError => e
      p e.message
      p 'click alert ok'
      @browser.alert.ok
    end
  end
  puts "#{brt}|901_Logout_Click"

rescue Selenium::WebDriver::Error::UnhandledAlertError => e

# 2015-08-18 03:43:53.680491500 "Error 400301: Not all transactions are displayed as the request has exceeded the maximum Number of returned transactions possible."
# 2015-08-18 03:43:55.138811500 "raising UnhandledAlertError"

  puts "rescue UnhandledAlertError"
  p @browser.alert.text

  if @browser.alert.text =~ /Error 400301: Not all transactions are displayed/
    puts "IGNORE Error 400301: Not all transactions are displayed"
    @browser.alert.ok
  else
    @browser.alert.ok
    p 'raising UnhandledAlertError'
    raise e
  end

rescue SystemExit => e
  p @browser.html
  puts e.message
  puts e.cause
  puts e.inspect
  puts e.backtrace.inspect
  p 'raising SystemExit'
  raise e
rescue StandardError => e

	# There are at least two variations of the 500 error.
	# They appear to originate from IBM_HTTP_Server; and from the page response
	# time (15 seconds), it could indicate an IHS plugin timeout or
	# configuration error in the plugin.xml where IHS is trying to connect
	# to a broken or non existent Java WebSphere process
# 
# /home/blt/tmp/ip-172-31-26-205-to-ib_nab_com_au_164.53.222.5.knox.log:2015-08-15 21:10:57.618495500 "<!DOCTYPE html PUBLIC \"-//IETF//DTD HTML 2.0//EN\"><html><head>\n<title>500 Internal Server Error</title>\n</head><body>\n<h1>Internal Server Error</h1>\n<p>The server encountered an internal error or\nmisconfiguration and was unable to complete\nyour request.</p>\n<p>Please contact the server administrator,\n you@your.address and inform them of the time the error occurred,\nand anything you might have done that may have\ncaused the error.</p>\n<p>More information about this error may be available\nin the server error log.</p>\n<hr>\n<address>IBM_HTTP_Server Server at ib.nab.com.au Port 443</address>\n\n</body></html>"
#
# /home/blt/tmp/nido-to-ib_nab_com_au_default.log:2015-08-20 18:53:56.200655500 "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>\n<title>Internal Server Error</title>\n</head><body>\n<h1>Internal Server Error - Read</h1>\nThe server encountered an internal error or misconfiguration and was unable to\ncomplete your request.<p>\nReference #3.408e0bd2.1440060800.3f3ba7c\n\n</p></body></html>"


  if @browser.h1(text: /Internal Server Error - Read/).present?
    p @browser.html
    puts "Exit. Internal Server Error - Read"
    exit 2
  end

  if @browser.alert.exists?
    p @browser.alert.text
    p 'alert exists. close'
    @browser.alert.close
  end

  begin
    @browser.screenshot.save ERROR_SCREENSHOT_FILE
  rescue Selenium::WebDriver::Error::UnhandledAlertError => e
    p @browser.alert.text
    p 'click alert close'
    @browser.alert.close
    @browser.screenshot.save ERROR_SCREENSHOT_FILE
  end
  p @browser.html
  puts e.message
  puts e.cause
  puts e.inspect
  puts e.backtrace.inspect
  p 'raising Exception'
  raise e

  # disable this test
  # otherwise account may be automatically locked
ensure
  @browser.quit
end

