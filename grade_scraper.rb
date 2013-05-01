require 'mechanize'
require 'nokogiri'
require 'net/smtp'

PITT_USERNAME = ''
PITT_PASSWORD = ''
GMAIL_USERNAME = ''
GMAIL_PASSWORD = ''
GRADE_URL = 'https://sisp.cssd.pitt.edu/psc/prdsis/EMPLOYEE/HRMS/c/SA_LEARNER_SERVICES.SSS_MY_CRSEHIST.GBL?PORTALPARAM_PTCNAV=HC_SSS_MY_CRSEHIST_GBL&EOPP.SCNode=HRMS&EOPP.SCPortal=EMPLOYEE&EOPP.SCName=CO_EMPLOYEE_SELF_SERVICE&EOPP.SCLabel=Self%20Service&EOPP.SCPTfname=CO_EMPLOYEE_SELF_SERVICE&FolderPath=PORTAL_ROOT_OBJECT.CO_EMPLOYEE_SELF_SERVICE.HCCC_ACADEMIC_RECORDS.HC_SSS_MY_CRSEHIST_GBL&IsFolder=false&PortalActualURL=https%3a%2f%2fsisp.cssd.pitt.edu%2fpsc%2fprdsis%2fEMPLOYEE%2fHRMS%2fc%2fSA_LEARNER_SERVICES.SSS_MY_CRSEHIST.GBL&PortalContentURL=https%3a%2f%2fsisp.cssd.pitt.edu%2fpsc%2fprdsis%2fEMPLOYEE%2fHRMS%2fc%2fSA_LEARNER_SERVICES.SSS_MY_CRSEHIST.GBL&PortalContentProvider=HRMS&PortalCRefLabel=My%20Course%20History&PortalRegistryName=EMPLOYEE&PortalServletURI=https%3a%2f%2fsisp.cssd.pitt.edu%2fpsp%2fprdsis%2f&PortalURI=https%3a%2f%2fsisp.cssd.pitt.edu%2fpsc%2fprdsis%2f&PortalHostNode=HRMS&NoCrumbs=yes&PortalKeyStruct=yes' 
STORAGE_FILE = '/tmp/grade_output'

def scrape_grades(username, password, grade_url)
  agent = Mechanize.new{ |a| a.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_0) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.65 Safari/537.31'
                             a.ssl_version, a.verify_mode = 'SSLv3', OpenSSL::SSL::VERIFY_NONE }

  page = agent.post(grade_url, userid: username, pwd: password)
  html = Nokogiri::HTML(page.body)

  results = []
  html.css('table').each do |t|
    results = t.content.gsub(/([\n]{8}|[\n]{2})/, ',').gsub(/\n/, '').split(',') if t[:class] == 'PSLEVEL1GRIDWBO'
  end

  grades = ""
  results.each_with_index do |r, ix|
    if r.include?(' Term ')
      grades << "Term: #{r}"
      grades << "\nClass: #{results[ix-1]}"
      grades << "\nGrade: #{results[ix+1]}"
      grades << "\n\n"
    end
  end
  grades
end

def grades_updated?(grades, storage_file)
  if grades != IO.read(storage_file)
    file = File.open(storage_file, 'w+')
    file.write(grades)
    updated = true
  end
rescue IOError => e
  puts "error..#{e}"
  updated = false
ensure
  file.close unless file == nil
  updated
end

def send_email(username, password, grades)
  message = <<EOF
From: SENDER <#{username}>
To: RECEIVER <#{password}>
Subject: GRADES UPDATED!!
#{grades}
EOF

  smtp = Net::SMTP.new('smtp.gmail.com', 587 )
  smtp.enable_starttls
  smtp.start('gmail.com', username, password, :login) do |smtp|
    smtp.send_message message, username, username
  end
end

grades = scrape_grades(PITT_USERNAME, PITT_PASSWORD, GRADE_URL)
send_email(GMAIL_USERNAME, GMAIL_PASSWORD, grades) if grades_updated?(grades, STORAGE_FILE)
