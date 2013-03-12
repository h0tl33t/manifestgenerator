#SBP File Generator

require_relative 'rateCheck'

	#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	Dir.chdir($targetPath)
	if $targetPath != '.'
		Dir.mkdir("#{$targetPath}\\Generated SBP Files\\") if File.directory?("#{$targetPath}\\Generated SBP Files\\") != true
	end
	#*********************************************************************************************************************************
	
class SBPGenerator
	def initialize()
		puts "Starting SBP file generation.."
		
		@mid = '900000616' #Temporarily hard coded for simplicity.  If necessary, can use setMID() to add in the user prompt for a MID.
		@sbpFields = ['Code', 'Date', 'Time', 'Tracking Number', 'Event Code', 'Entry Facility ZIP', 'Space 1', 'Destination ZIP Code', 'Space 2', 'Weight', 'Length', 'Height', 'Width', 'Overlabel']
		@mailClasses = []
		@allDetails = []
		@domClasses = []
		@intClasses = []
		@headerFields = []
		@detailFields = []
		@headerVals = {}
		@detailVals = {}
		@detailRecords = []
		@mailClass = ''
		@baselineFile = "#{File.dirname(__FILE__)}\\baseline.raw"
		@stcs = "#{File.dirname(__FILE__)}/sbp_stcs.csv"
		@rateFile = "#{File.dirname(__FILE__)}\\rates.csv"
		@events = "#{File.dirname(__FILE__)}\\sbp_event_codes.csv"
		@fileName = ''
		@rateIngredients = []
		@stcList = []
		@stc = ''
		@firstServiceCode = ''
		@secondServiceCode = ''
		@eventCode
		@eventList = []
		@originZIP = '20260'  #Temporarily hard coded for simplicity.
		@facilityZIP = '20260'#Temporarily hard coded for simplicity.
		@recordCount = 0
		@time = Time.now.strftime('%H%M%S')
		@date = Time.now.strftime('%Y%m%d')
		#@date = '20130113' #Temp test date.
		@permit = ''
		@permitZIP = ''
		@type = '1'
		@isDomestic = false
		@eligible = true   #Eligible for manifest-based? PRS Full Network are not.
		@isReturns = false #Returns product?  Used to set type to '3' and permit/permit ZIP to MR-type permit.
		@cmFlats = false
		@cmLetters = false
		
		@nsa = false
		
		@rateCheck = RateCheck.new()
		
		pullClasses("#{File.dirname(__FILE__)}\\mailclasses.txt")
		pullSTCs()
		selectSTC()
		@isManifestBased = false if not @eligible
		@isManifestBased = checkMailerType() if @eligible
		generateManifest() if @isManifestBased
		generateSBP()
		exit()
	end
	#*********************************************************************************************************************************
	def prompt()
		print "> "
	end
	#*********************************************************************************************************************************
	def exit()
		puts "Press any key to exit the program."
		prompt()
		gets()
	end
	#*********************************************************************************************************************************
	#Pull Mail Classes
	def pullClasses(filename)
		classList = File.open(filename)
		@mailClasses = classList.gets.split(',')
		classList.close()
		
		@domClasses = @mailClasses.dup
		@domClasses.keep_if do |mail|
			['BB','BL','BS','CM','EX','FC','LW','PM','PS','RP','S2','SA'].include?(mail)
			#['BB','BL','BP','BS','CM','EX','FC','LW','PM','PS','RP','S2','SA'].include?(mail) #Has invalid/removed mail classes for negative testing.
		end
		
		@intClasses = @mailClasses.dup
		@intClasses.keep_if do |mail|
			['IE', 'LC', 'PG', 'CP'].include?(mail)
		end
	end
	#*********************************************************************************************************************************
	def pullSTCs()
		eachSTC = {}
		stcFile = File.open(@stcs, 'r')
		fieldNames = stcFile.readline.chomp.split(',')
		stcFile.each_line do |row|
			stc = row.chomp.split(',')
			fieldNames.each_with_index do |field, index|
				eachSTC.merge!(field => stc[index]) if stc[index] != nil
				eachSTC.merge!(field => '') if stc[index] == nil
			end

			@stcList << eachSTC.dup if eachSTC.empty? == false
			eachSTC.clear
		end
		stcFile.close()
	end
	#*********************************************************************************************************************************
	def selectSTC()
		sbpListSize = @stcList.size
		validSTCs = {}
		puts "Enter the 3-digit STC to create the SBP file with:"
		@stcList.each_with_index do |stc, i|
			entry = "#{stc['Service Type Code']}, #{stc['Mail Class']}, #{stc['Description']}"
			puts "#{i+1}) #{entry}"
			validSTCs.merge!(stc['Service Type Code'] => entry)
		end
		prompt
		selection = gets.chomp
		while not validSTCs.keys.include?(selection)
			puts "#{selection} is not a valid STC, please enter a valid 3-digit STC code:"
			prompt
			selection = gets.chomp
		end
		
		@stcList.each {|stc| @stc, @mailClass, @firstServiceCode, @secondServiceCode = stc['Service Type Code'], stc['Mail Class'], stc['Extra Service Code 1st Service'], stc['Extra Service Code 2nd Service'] if stc['Service Type Code'] == selection}
		puts "You selected: #{validSTCs[selection]}"
		@isDomestic = true if @domClasses.include?(@mailClass)
		@eligible = false if /PRS Full Network/.match(validSTCs[selection]) != nil
		@isReturns = true if /Return/.match(validSTCs[selection]) != nil
		@cmFlats = true if ['741','799'].include?(selection)   #Catch Critical Mail Flats
		@cmLetters = true if ['740','816'].include?(selection) #Catch Critical Mail Letters
	end
	#*********************************************************************************************************************************
	#Manifest Generator
	def generateManifest()
		puts "Generating a manifest for a manifest-based SBP mailer!"
		pullHeaderFields("#{File.dirname(__FILE__)}\\header.csv")
		pullDetailFields("#{File.dirname(__FILE__)}\\detail.csv")
		baseline()
		setFileType()
		fileNameGen('manifest')
		pullRates()
		details = detailGen()	
		if details.empty? == false
			file = File.open("#{@fileName}.raw", 'w')
			file.write(headerGen())
			details.each do |line|
				file.write("\n")
				file.write(line)
			end
			file.close()
			buildCEW()
			buildSEM()
			puts "Built manifest (.raw/.cew/.sem) for STC #{@stc} (Mail Class: #{@mailClass})!"
		end
		details.clear
	end
	#*********************************************************************************************************************************
	#SBP File Generator
	def generateSBP()
		line = []
		first = true
		puts "Generating SBP files.."
		pickScanEvent()
		fileNameGen('sbp')
		sbpFile = File.open("#{@fileName}.dat", 'w')
		details = sbpDetailGen()
		details.each do |line|
			if first
				sbpFile.write(line)
				first = false
			else
				sbpFile.write("\n")
				sbpFile.write(line)
			end
		end
		sbpFile.close()
		buildSEM()
		puts "Built SBP file (.dat/.sem) for STC #{@stc} and Event Code #{@eventCode}!"
		sampleGen()
	end
	#*********************************************************************************************************************************
	def checkMailerType()
		puts "Is this SBP file manifest-based? (y/n)"
		prompt
		choice = gets.chomp.downcase
		return true if choice == 'y'
		return false if choice != 'y'
	end
	#*********************************************************************************************************************************
	def isNSA()
		puts "Do you want to generate this file for NSA rate purposes (y/n)? (Utilizes Custom Contracts, MID 911911911, PI 911)"
		prompt
		answer = gets.chomp.downcase
		if answer == 'y'
			puts "The generator will utilize the NSA mailer Custom Contracts (MID 911911911, PI 911)"
			@mid = '911911911'
			@permit = '911'
		end
		@nsa = true
	end
	#*********************************************************************************************************************************
	def pickScanEvent()
		validCodes = []
		pullEvents()
		puts "What SBP Scan Event Code do you want to utilize in the SBP File? (Enter a 2-digit code from the list below)"
		@eventList.each do |event|
			puts "#{event.values[0]} - #{event.values[1]}"
			validCodes << event.values[0]
		end
		prompt
		code = gets.chomp
		while not validCodes.include?(code)
			puts "'#{code}' is not a valid SBP Scan Event Code.  Re-enter a valid code:"
			prompt
			code = gets.chomp
		end
		@eventCode = code
	end
	#*********************************************************************************************************************************
	def pullEvents()
		eachEvent = {}
		eventFile = File.open(@events, 'r')
		fieldNames = eventFile.readline.chomp.split(',')
		eventFile.each_line do |row|
			event = row.chomp.split(',')
			fieldNames.each_with_index do |field, index|
				eachEvent.merge!(field => event[index]) if event[index] != nil
				eachEvent.merge!(field => '') if event[index] == nil
			end

			@eventList << eachEvent.dup if eachEvent.empty? == false
			eachEvent.clear
		end
		eventFile.close()
	end
	#*********************************************************************************************************************************
	def setMID()
		puts "What is the Mailer ID you'd like to use for the file?"
		prompt
		@mid = gets.chomp
		while @mid.length != 9
			puts "#{@mid} is not a valid 9-digit MID.  Please re-enter a mid:"
			prompt
			@mid = gets.chomp
		end
	end
	#*********************************************************************************************************************************
	#Pull Header Fields
	def pullHeaderFields(filename)
		headerFile = File.open(filename)
		@headerFields = headerFile.gets.split(',')
		headerFile.close()
	end
	#*********************************************************************************************************************************
	#Pull Detail Fields
	def pullDetailFields(filename)
		detailFile = File.open(filename)
		@detailFields = detailFile.gets.split(',')
		detailFile.close()
	end
	#*********************************************************************************************************************************
	def baseline()
		count = 0
		file = File.open(@baselineFile, 'r')
		file.each_line do |line|
			array = line.chomp.split('|')
			if count == 0
				@headerFields.each_with_index do |field, i|
					@headerVals.merge!(field => array[i]) if array[i] != nil
					@headerVals.merge!(field => '') if array[i] == nil
				end
			else
				@detailFields.each_with_index do |field, i|
					@detailVals.merge!(field => array[i]) if array[i] != nil
					@detailVals.merge!(field => '') if array[i] == nil
				end
			end
			count = count + 1
		end
		file.close()
	end
	#*********************************************************************************************************************************
	#Pull Rates -- take (mailClass)
	def pullRates()
		rateCount = 0
		eachRate = {}
		rateFile = File.open(@rateFile, 'r')
		fieldNames = rateFile.readline.chomp.split(',')
		rateFile.each_line do |row|
			rate = row.chomp.split(',')
			if rate[0] == @mailClass
				fieldNames.each_with_index do |field, index|
					eachRate.merge!(field => rate[index])
				end
				rateCount = rateCount + 1
			end
			@rateIngredients << eachRate.dup if eachRate.empty? == false
			eachRate.clear
		end
		rateFile.close()
	end
	#*********************************************************************************************************************************
	#Insurance Check -- provide strings to populate 'Value of Article' based on insurance STCs, either '0000000' for 930 or '0050000' for 931
	def insCheck(stc)
		if stc == '930' #Insurance <= $200
			return '0010000' # $100
		elsif stc == '931' #Insurance > $200
			return '0050000' # $500
		else
			return false #No insurance extra service.
		end
	end
	#*********************************************************************************************************************************
	#EFN Generator -- take (MID)
	def efnGen()
		classIdentifier = (@mailClasses.index(@mailClass) + 1).to_s.rjust(2, '0')
		return "92750#{@mid}#{classIdentifier}#{rand(999999).to_s.rjust(6, '0')}"
	end
	#*********************************************************************************************************************************
	#PIC Generator -- take (MID, STC)
	def picGen(stc)
		if @isDomestic
			return "420#{@originZIP}000092#{stc}#{@mid}#{rand(99999999).to_s.rjust(8, '0')}"
		else
			case @mailClass
			when 'LC'
				return "LX600#{rand(999999).to_s.rjust(6, '0')}US"
			when 'PG'
				return "83500#{rand(99999).to_s.rjust(5, '0')}"
			when 'IE'
				return "AA100#{rand(999999).to_s.rjust(6, '0')}US"
			when 'CP'
				return "CB600#{rand(999999).to_s.rjust(6, '0')}US"
			end
		end
	end
	#*********************************************************************************************************************************
	#Zone Calc -- take (minZone, maxZone)
	def zoneCalc(minZone, maxZone)
		minZone = '01' if minZone == 'LC'
		if minZone != '00' and maxZone != '00'
			return rand(minZone.to_i..maxZone.to_i).to_s.rjust(2, '0')
		else
			return '00'
		end
	end
	#*********************************************************************************************************************************
	#Valid ZIP Generator -- take (ZONE)
	def validZIP(zone)
		zips = {'00' => '20260', '01' => '20260', '02' => '24001', '03' => '25505', '04' => '35601', '05' => '61001', '06' => '74333', '07' => '87501', '08' => '90210'}
		return zips[zone]
	end
	#*********************************************************************************************************************************
	#Valid Weight Generator -- take (minWeight, maxWeight)
	def validWeight(minWeight, maxWeight)
		min = minWeight.to_f
		max = maxWeight.to_f
		
		part = rand(min..max).round(4).to_s.split('.')
		wholeNum = part[0].rjust(5,'0')
		decimal = part[1].ljust(4,'0')
		return wholeNum + decimal
	end
	#*********************************************************************************************************************************
	#Required Volume Check -- take (rateInd) and return dimensions (length, height, width)
	def volumeCheck(rateInd)
		minVolumeRequired = ['DR', 'DN']
		validVolumeRequired = ['CP', 'P5', 'P6', 'P7', 'P8', 'P9']
		
		if minVolumeRequired.include?(rateInd)
			return '01400' #14 inches (1728 cubic inches is minimum for DR/DN...DN volume is multiplied by 0.785)
		elsif validVolumeRequired.include?(rateInd)
			minVol = 0.00
			maxVol = 12.00  #9.50 will go to 0.49 (Tier 5).  Anything above will test recalculation to SP from CP.
			part = rand(minVol..maxVol).round(2).to_s.split('.')
			wholeNum = part[0].rjust(3, '0')
			decimal = part[1].ljust(2, '0')
			return wholeNum + decimal
		else
			return false
		end
	end
	#*********************************************************************************************************************************
	#International Country Code and Zone Calculation
	def getIntInfo()
		if @mailClass == 'PG'
			info = {'CA' => 'Price Group 1', 'MX' => 'Price Group 2', 'HK' => 'Price Group 3', 'AL' => 'Price Group 4', 'FI' => 'Price Group 5', 'IN' => 'Price Group 6', 'DO' => 'Price Group 7', 'PE' => 'Price Group 8'}
			temp = info.keys
			countryCode = temp[rand(temp.size)]
			return countryCode, info[countryCode]
		else
			info = {'CA' => 'Price Group 1', 'MX' => 'Price Group 2', 'HK' => 'Price Group 3', 'AL' => 'Price Group 4', 'FI' => 'Price Group 5', 'IN' => 'Price Group 6', 'CM' => 'Price Group 7', 'EG' => 'Price Group 8', 'JM' => 'Price Group 9'}
			temp = info.keys
			countryCode = temp[rand(temp.size)]
			return countryCode, info[countryCode]
		end
	end
	#*********************************************************************************************************************************
	#Filename Generator
	def fileNameGen(type)
		@fileName = "#{$targetPath}\\Generated SBP Files\\autogenerated_#{@date}_#{@time}_#{@stc}_SBP" if type == 'manifest'
		@fileName = "#{$targetPath}\\Generated SBP Files\\PTS-SBP-Extract-#{@date}_#{@stc}_#{@eventCode}" if type == 'sbp'
	end
	#*********************************************************************************************************************************
	#Set File Type - set type based on the mail class.  Necessary to appropriately handle return-type products (MR and RP).
	def setFileType()
		if @isReturns
			@permit = '8203001'
			@permitZIP = '20024'
			@type = '3'
		else
			@permit = '963'
			@permitZIP = '90036'
			@type = '1'
		end
	end
	#*********************************************************************************************************************************
	#Header Generator
	def headerGen()
		header = ''
		@headerVals['Electronic File Number'] = efnGen()
		@headerVals['Electronic File Type'] = @type
		@headerVals['Date of Mailing'] = @date
		@headerVals['Time of Mailing'] = @time
		@headerVals['Entry Facility ZIP Code'] = @facilityZIP
		@headerVals['Transaction ID'] = @date + '0000'
		@headerVals['File Record Count'] = (@recordCount + 1).to_s.rjust(9, '0')
		@headerVals['Mailer ID'] = @mid
		
		@rateCheck.grabEFN(@headerVals['Electronic File Number'])
			
		@headerVals.each_value do |value|
			header = header + "#{value}|"
		end
		return header
	end
	#*********************************************************************************************************************************
	#Detail Generator
	def detailGen()
		#isNSA() if @nsa == false #Checks to see if user wants to utilize NSA mailer information or not.  Only runs once according to @nsa.
		
		@detailVals['Mail Class'] = @mailClass
		@detailVals['Mail Owner Mailer ID'] = @mid
		@detailVals['Payment Account Number'] = @permit
		@detailVals['Post Office of Account ZIP Code'] = @permitZIP
		
		return buildDom() if @isDomestic
		return buildInt() if @isDomestic == false
	end
	#*********************************************************************************************************************************
	#Build Domestic Detail Records
	def buildDom()
		pullRates()
		baseline = @detailVals.dup
		detail = ''
		details = []
		@recordCount = 0
		@rateIngredients.each do |rate|
			rate.each do |key, val|
				baseline[key] = val if baseline.has_key?(key)
			end
			
			if rate['Processing Category'] == 'O' #Catch Open & Distribute
				next
			elsif @cmLetters and rate['Rate Indicator'] != 'AL'
				next
			elsif @cmFlats and rate['Rate Indicator'] != 'AF'
				next
			else
				baseline['Service Type Code'] = @stc
				baseline['Extra Service Code 1st Service'] = @firstServiceCode
				baseline['Extra Service Code 2nd Service'] = @secondServiceCode
				baseline['Tracking Number'] = picGen(@stc)
				[@stc, @firstServiceCode, @secondServiceCode].each do |code|
					ins = insCheck(code)
					baseline['Value of Article'] = ins if ins != false
					baseline['COD Amount Due Sender'] = '0005000' if @stc == '915' #If COD STC, fill COD Amount Due Sender to $50
				end
					
				#Catch any rates with Discount Type Codes
				baseline['Discount Type'] = rate['Discount and Surcharge'] if rate['Discount and Surcharge'] != '*'
					
				#Catch Non-Profit SA and S2 Rate Ingredients (for both published and NSA)
				if (@mailClass == 'S2' or @mailClass == 'SA') and ['N5', 'ND', 'NM', 'NT', 'NR', 'NH', 'NB'].include?(rate['Rate Indicator'])
					baseline['Payment Account Number'] = '333' if @mid == '990001337'
					baseline['Payment Account Number'] = '9911' if @mid == '911911911'
				end

				baseline['Domestic Zone'] = zoneCalc(rate['Min Zone'], rate['Max Zone'])
				baseline['Destination ZIP Code'] = validZIP(baseline['Domestic Zone'])
				baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])
					
				baseline['Domestic Zone'] = '08' if rate['Rate Indicator'] == 'PM' #Catch Priority Mail 'PM' which requires ZIP starting in 963 = Zone 8.
				baseline['Destination ZIP Code'] = '96303' if rate['Rate Indicator'] == 'PM' #Assign 93603.
					
				volCheck = volumeCheck(rate['Rate Indicator'])
				if volCheck != false
					baseline['Length'] = volCheck
					baseline['Width'] = volCheck
					baseline['Height'] = volCheck
				end
					
				baseline.each_value do |value|
					detail = detail + "#{value}|"
				end
					
				@rateCheck.check(baseline)
				@recordCount = @recordCount + 1
				details << detail
				detail = ''
				@allDetails << baseline.dup
				baseline.clear
				baseline = @detailVals.dup
			end
		end
		return details
	end
	#*********************************************************************************************************************************
	#Build International Detail Records
	def buildInt()
		pullRates()
		baseline = @detailVals.dup
		detail = ''
		details = []
		
		if @mailClass == 'PG'
			baseline['Barcode Construct Code'] = 'G01'
		else
			baseline['Barcode Construct Code'] = 'I01'
		end
		
		baseline['Foreign Postal Code'] = '123456789'
		
		@rateIngredients.each do |rate|
			rate.each do |key, val|
				baseline[key] = val if baseline.has_key?(key)
			end
			
			baseline['Destination Country Code'], baseline['Customer Reference Number 1'] = getIntInfo()
			baseline['Tracking Number'] = picGen('')
			baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])

			baseline.each_value do |value|
				detail = detail + "#{value}|"
			end
			
			@rateCheck.check(baseline)
			@recordCount = @recordCount + 1
			details << detail
			detail = ''
		end
		@allDetails << baseline.dup
		baseline.clear
		baseline = @detailVals.dup
		return details
	end
	#*********************************************************************************************************************************
	#SBP Detail Record Generator
	def sbpDetailGen()
		lineContents = []
		detail = ''
		details = []
		
		if @isManifestBased
			@allDetails.each do |detailRecord|
				lineContents << "010"
				lineContents << Time.now.strftime('%m/%d/%Y')
				lineContents << Time.now.strftime('%H.%M.%S')
				lineContents << detailRecord['Tracking Number']
				lineContents << @eventCode
				lineContents << @facilityZIP
				lineContents << ''.rjust(4,' ') #4-char white space
				lineContents << detailRecord['Destination ZIP Code']
				lineContents << ''.rjust(4,' ') #4-char white space
				lineContents << ''.rjust(9,' ') #9-char white space
				lineContents << ''.rjust(7,' ') #7-char white space
				lineContents << ''.rjust(7,' ') #7-char white space
				lineContents << ''.rjust(7,' ') #7-char white space
				lineContents << ''.rjust(34,' ')#34-char white space
				details << formatLine(lineContents)
				lineContents.clear
			end
		else
			puts "How many records do you want to generate?"
			prompt
			number = gets.chomp
			while number.to_i <= 0
				puts "#{number} is not a valid number.  Please enter a positive integer value."
				prompt
				number = gets.chomp
			end
			
			number.to_i.times do 
				lineContents << "010"
				lineContents << Time.now.strftime('%m/%d/%Y')
				lineContents << Time.now.strftime('%H.%M.%S')
				lineContents << picGen(@stc)
				lineContents << @eventCode
				lineContents << @facilityZIP
				lineContents << ''.rjust(4,' ') #4-char white space
				lineContents << validZIP(zoneCalc('00', '08'))
				lineContents << ''.rjust(4,' ') #4-char white space
				lineContents << ''.rjust(9,' ') #9-char white space
				lineContents << ''.rjust(7,' ') #7-char white space
				lineContents << ''.rjust(7,' ') #7-char white space
				lineContents << ''.rjust(7,' ') #7-char white space
				lineContents << ''.rjust(34,' ')#34-char white space
				details << formatLine(lineContents)
				lineContents.clear
			end
		end
		return details
	end
	#*********************************************************************************************************************************
	#Format SBP File Detail Record
	def formatLine(contents)
		first = true
		detail = ''
		contents.each do |val|
			detail = detail + "\"" + val + "\"" if first
			detail = detail + "," + "\"" + val + "\"" if not first
			first = false
		end
		return detail
	end
	#*********************************************************************************************************************************
	#Build CEW File
	def buildCEW()
		tempEFN = @headerVals['Electronic File Number']
		cewFields = [@mid, tempEFN[14..21], @date, @time, @facilityZIP, @date, (@recordCount + 1).to_s, '0', (@recordCount + 1).to_s, @recordCount.to_s, '']
		
		cewFile = File.open("#{@fileName}.cew", 'w')
		cewFields.each do |val|
			cewFile.write(val + ',')
		end
		cewFile.close()
	end
	#*********************************************************************************************************************************
	#Build SEM File
	def buildSEM()
		semFile = File.open("#{@fileName}.sem", 'w')
		semFile.close()
	end
	#*********************************************************************************************************************************
	#Handler for Sample Building
	def sampleGen()
		puts "Enter 's' to generate a sample for this file.  (Anything else to continue without building a sample.)"
		prompt
		input = gets.downcase.chomp
		if input == 's'
			@allDetails.delete_if {|detail| detail['Barcode'] != '1'}
			if @domClasses.include?(@mailClass) #Allows for selection of valid sample types for Domestic Mail Classes
				puts "What type of sample file? 'i' for IMD, 'pass' for PASS, 'pos' for POS, or 's' for STATS."
				prompt
				sType = gets.downcase.chomp
				while not ['i', 'pass', 'pos', 's'].include?(sType)
					puts "#{sType} is not a valid selection.  Please enter 'i' for IMD, 'pass' for PASS, 'pos' for POS, or 's' for STATS."
					prompt
					sType = gets.downcase.chomp
				end
				case sType #Sample Type
				when 'i' #IMD
					buildIMD()
				when 'pass' #PASS
					buildPASS()
				when 'pos' #POS
					buildPOS()
				when 's' #STATS
					buildSTATS()
				end
			elsif @intClasses.include?(@mailClass) #Allows for selection of valid sample types for International Mail Classes
				puts "What type of sample file? 'i' for IMD or 's' for STATS."
				prompt
				sType = gets.downcase.chomp
				while not ['i', 'pass', 'pos', 's'].include?(sType)
					puts "#{sType} is not a valid selection.  Please enter 'i' for IMD, 'pass' for PASS, 'pos' for POS, or 's' for STATS."
					prompt
					sType = gets.downcase.chomp
				end
				case sType #Sample Type
				when 'i' #IMD
					buildIMD()
				when 's' #STATS
					buildSTATS()
				end
			end
		end
	end
	#*********************************************************************************************************************************
	#Builds out an IMD File
	def buildIMD()
		#DDU = D, SCF = S, NDC = B, ASF = F, None = N
		facilityTypes = {'D' => '1', 'S' => '2', 'B' => '3', 'F' => '4', 'N' => '5'} 
		lines = []
		sampleCount = 0
		facilityTypes.keys.each do |dri|
			@allDetails.each do |d|
				if d['Destination Rate Indicator'] == dri
					pic = d['Tracking Number'].ljust(34, ' ')
					weight = imdWeight(d['Weight'])
					length = imdSize(d['Length'])
					height = imdSize(d['Height'])
					width = imdSize(d['Width'])
					girth = imdSize(d['Dimensional Weight'])
					zip = d['Destination ZIP Code'] if @domClasses.include?(d['Mail Class'])
					zip = '00000' if @intClasses.include?(d['Mail Class'])
			
					rateType = imdRate(d['Rate Indicator'])
					if d['Mail Class'] == 'IE'
						if d['Rate Indicator'] == 'E4'
							shape = 'F4'
							sortation = 'NA'
						elsif d['Rate Indicator'] == 'E6'
							shape = 'F6'
							sortation = 'NA'
						elsif d['Rate Indicator'] == 'E8'
							shape = 'F8'
							sortation = 'NA'
						elsif d['Rate Indicator'] == 'PA'
							shape = 'NA'
							sortation = 'PA'
						else
							if rateType == 'shape'
								shape = d['Rate Indicator']
								sortation = 'NA'
							elsif rateType == 'sortation'
								sortation = d['Rate Indicator']
								shape = 'NA'
							else
								next
							end
						end
					else
						if rateType == 'shape'
							shape = d['Rate Indicator']
							sortation = 'NA'
						elsif rateType == 'sortation'
							sortation = d['Rate Indicator']
							shape = 'NA'
						else
							next
						end
					end
			
					countryCode = '  ' if @domClasses.include?(d['Mail Class'])
					countryCode = d['Destination Country Code'] if @intClasses.include?(d['Mail Class'])
			
					sampleLine = "    D#{pic}#{weight}#{length}#{height}#{width}#{girth}#{zip}YN#{shape}#{d['Processing Category']}NNNNNNNNNNNN0.0000000N#{d['Mail Class']}#{sortation}N     NA     NANNA#{' '.ljust(240, ' ')}#{countryCode}        #{Time.now.strftime('%m%d%Y')}#{@time}NNNNNNNNNN"
					#sampleLine = "    D#{pic}#{weight}#{length}#{height}#{width}#{girth}#{zip}YN#{shape}#{d['Processing Category']}NNNNNNNNNNNN0.0000000N#{d['Mail Class']}#{sortation}N     NA     NANNA#{' '.ljust(240, ' ')}#{countryCode}        01132013#{@time}NNNNNNNNNN"
					lines << sampleLine
					sampleCount = sampleCount + 1
				end
			end
			if sampleCount > 0
				numRecords = sampleCount.to_s.rjust(3, '0')
				imdFileName = @fileName.gsub(/PTS-SBP-Extract-/, 'SBP_')
				imdFile = File.open("#{imdFileName}_IMD_#{dri}.evs", 'w')
				imdHeader = ("eVS1H#{@facilityZIP}     #{facilityTypes[dri]}#{Time.now.strftime("%m%d%Y")}THDSN0  N#{numRecords}#{@mid}3.0     NN030").ljust(112, ' ')
				#imdHeader = ("eVS1H#{@facilityZIP}     #{facilityTypes[dri]}01132013THDSN0  N#{numRecords}#{@mid}3.0     NN030").ljust(112, ' ') #Hard-coded date for date-sensitive testing.
				imdFile.write(imdHeader)
				lines.each do |line|
					imdFile.write("\n")
					imdFile.write(line)
				end
				imdFile.close()
				imdSem = File.open("#{imdFileName}_IMD_#{dri}.sem", 'w')
				imdSem.close()
				lines.clear()
				sampleCount = 0
				puts "Built SBP IMD sample (.evs/.sem) for STC #{@stc} and Facility Type #{dri}!"
			end
		end
	end
	#*********************************************************************************************************************************
	#Determine IMD Rate Indicator
	def imdRate(rate)
		shapeFile = File.open("#{File.dirname(__FILE__)}\\shapeIndicators.csv", 'r') #Get shape-based rate indicators
		shapes = shapeFile.gets.split(',')
		shapeFile.close()
		return 'shape' if shapes.include?(rate)
		
		sortationFile = File.open("#{File.dirname(__FILE__)}\\sortationLevels.csv", 'r') #Get sortation levels
		sortations = sortationFile.gets.split(',')
		sortationFile.close()
		return 'sortation' if sortations.include?(rate)
	end
	#*********************************************************************************************************************************
	#Re-format weight for IMD Files
	def imdWeight(value)
		wholeNum = value[2, 2]
		decimal = value[5, 4]
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Re-format dimensions for IMD Files
	def imdSize(value)
		wholeNum = value[0,3] #Pulls the whole number portion of the eVS dimension/size convention
		decimal = value[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}".ljust(7, '0')
	end
	#*********************************************************************************************************************************
	#Re-format weight for STATS Files
	def statsWeight(value)
		pounds = value[1, 3]
		ounces = ((('0.' + value[5, 4]).to_f)*16).round(1).to_s
		ounces = ounces.to_f.round().to_s.rjust(3, ' ') if ounces.size > 3
		return pounds, ounces
	end
	#*********************************************************************************************************************************
	#Re-format dimensions for STATS Files
	def statsSize(value)
		wholeNum = value[0,3] #Pulls the whole number portion of the eVS dimension/size convention
		decimal = value[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}".to_f.round.to_s
	end
	#*********************************************************************************************************************************
	#Calculates STATS Value for Mail Class
	def statsClass(value)
		if value == 'FC'
			return '10' #Code for First Class Mail
		elsif value == 'PM' or value == 'CM'
			return '20' #Code for Priority Mail
		elsif value == 'S2'
			return '40' #Code for Standard
		elsif value == 'SA'
			return '90' #Code for Standard Non-Profit
		elsif value == 'CP'
			return '7G' #Code for Priority Mail International
		elsif value == 'LC'
			return '7K' #Code for FCPIS
		elsif value == 'PG' or value == 'IE'
			return '70' #Code for GxG or EMI
		elsif value == 'BB'
			return '52' #Code for Bound Printed Matter
		elsif value == 'BL'
			return '54' #Code for Library Mail
		elsif value == 'BS'
			return '53' #Code for Media Mail
		elsif value == 'RP'
			return '5I' #Code for PRS
		elsif value == 'PS'
			return '5H' #Code for Parcel Select
		else
			return '50' #Package Services Default
		end
	end
	#*********************************************************************************************************************************
	#Determine Shape Value for STATS Samples, takes (Processing Category, Rate Indicator)
	def statsShape(pc, ri)
		if pc == '1'
			return '3' if ri == 'E3' or ri == 'E4' #Flat Rate Envelope
			return '1'  #Letters
		elsif pc == '2'
			return '3' if ri == 'E3' or ri == 'E4' or ri == 'FE' #Flat Rate Envelope
			return 'I' if ri == 'E5' or ri == 'E6' or ri == 'E7' #Legal Flat Rate Envelope
			return '9' if ri == 'FP' #Flat Rate Padded Envelope
			return '2'  #Flats
		elsif pc == '3'
			return 'J' if ri == 'C6'
			return 'K' if ri == 'C7'
			return 'L' if ri == 'C8'
			return '8' if ri == 'E8' or ri == 'E9' or ri == 'EE' #Regular/Medium Flat Rate Box
			
			return '5' #Parcels
		elsif pc == '4'
		
			return '5' #Parcels
		elsif pc == '5'
			return '9' if ri == 'FP' #Flat Rate Padded Envelope
			return 'F' if ri == 'FS' #Small Flat Rate Box
			return '8' if ri == 'FB' #Regular/Medium Flat Rate Box
			return 'D' if ri == 'PL' #Large Flat Rate Box
			return 'E' if ri == 'PM' #Large Flat Rate Military Box
			return '5' #Parcels
		elsif pc == 'O'
			return '7' #PMOD/Pallets
		else
			return '0' #Default/Fill
		end
	end
	#*********************************************************************************************************************************
	#Builds out a STATS File Version 2
	def buildSTATSv2()
		lines = []
		count = 0
		mclass = ''
		
		@allDetails.each do |d| #d is each detail record in hash format
			count = count + 1
			pic = d['Tracking Number'].ljust(34, ' ')
			pounds, ounces = statsWeight(d['Weight'])
			classInfo = statsClass(d['Mail Class'])
			mclass = d['Mail Class']
			shape = statsShape(d['Processing Category'], d['Rate Indicator'])
			
			case d['Processing Category']
				when '3'
					mailable = '1' #Machinable
				when '5'
					mailable = '2' #Non-machinable
				else
					mailable = '0' #Default/Fill
			end
			
			length = statsSize(d['Length']).rjust(3, ' ')
			height = statsSize(d['Height']).rjust(2, ' ')
			width = statsSize(d['Width']).rjust(2, ' ')
			
			if @intClasses.include?(d['Mail Class'])
				zip = '     '
				countryType = '1' if d['Destination Country Code'] == 'CA'
				countryType = '1' if d['Destination Country Code'] != 'CA'
				countryCode = d['Destination Country Code']
			else
				zip = d['Destination ZIP Code']
				countryType = '0'
				countryCode = '  0'
			end
			
			sampleLine = "661204THDSN0#{@date}RESC#{@time}99901#{count.to_s.rjust(4, '0')} 0                    1#{pounds}#{ounces}#{classInfo}00#{shape}#{mailable}00000#{@originZIP}#{zip}#{length}#{height}#{width}01000#{countryType}    0#{@date}0000002000#{countryCode}#{' '.rjust(20, ' ')}000  #{' '.rjust(13, ' ')}#{@date}01        #{pic}00         000000000000100001000000000000000000000000#{' '.rjust(144, ' ')}000000#{' '.rjust(66, ' ')}"
			lines << sampleLine
		end
		statsFile = File.open("#{$targetPath}\\Generated SBP Files\\STATS_#{@date}#{@time}SBP_#{@stc}.DAT", 'w')
		lines.each do |line|
			statsFile.write("\n") if line != lines[0]
			statsFile.write(line)
		end
		statsSem = File.open("#{$targetPath}\\Generated SBP Files\\STATS_#{@date}#{@time}SBP_#{@stc}.sem", 'w')
		statsSem.close()
		puts "Built SBP STATS sample (.DAT/.sem) for STC #{@stc}!"
	end
	#*********************************************************************************************************************************
	#Builds out a STATS File Version 1
	def buildSTATS()
		lines = []
		count = 0
		mclass = ''
		
		@allDetails.each do |d| #d is each detail record in hash format
			count = count + 1
			pic = d['Tracking Number'].ljust(34, ' ')
			pounds, ounces = statsWeight(d['Weight'])
			ounces = ounces.rjust(4, ' ')
			classInfo = statsClass(d['Mail Class'])
			mclass = d['Mail Class']
			shape = statsShape(d['Processing Category'], d['Rate Indicator'])
			length = statsSize(d['Length']).rjust(3, '0')
			height = statsSize(d['Height']).rjust(2, '0')
			width = statsSize(d['Width']).rjust(2, '0')
			
			if @intClasses.include?(d['Mail Class'])
				zip = '     '
				countryType = '1' if d['Destination Country Code'] == 'CA'
				countryType = '1' if d['Destination Country Code'] != 'CA'
				countryCode = d['Destination Country Code']
			else
				zip = d['Destination ZIP Code']
				countryType = '0'
				countryCode = '  0'
			end
			
			sampleLine = "#{@date}5405315#{count.to_s.rjust(4, ' ')}#{pounds}#{ounces}   1#{classInfo}#{shape}K000#{length}#{height}#{width}0100#{@originZIP}#{pic}0#{@mid}#{zip}01THDSN0#{@date}000000   0#{@originZIP[0,3]}"
			lines << sampleLine
		end
		statsFile = File.open("#{$targetPath}\\Generated SBP Files\\STATS_#{@date}#{@time}SBP_#{@stc}.DAT", 'w')
		lines.each do |line|
			statsFile.write("\n") if line != lines[0]
			statsFile.write(line)
		end
		statsSem = File.open("#{$targetPath}\\Generated SBP Files\\STATS_#{@date}#{@time}SBP_#{@stc}.sem", 'w')
		statsSem.close()
		puts "Built SBP STATS sample (.DAT/.sem) for STC #{@stc}!"
	end
	#**********************************************
	#Builds out a PASS Sample
	def buildPASS()
		lines = []
		count = 0
		mclass = ''
		
		@allDetails.each do |d| #d is each detail record in hash format
			count = count + 1
			mclass = d['Mail Class']
			pic = d['Tracking Number'].ljust(34, ' ')
			weight = passWeight(d['Weight'])
			length = passSize(d['Length'])
			height = passSize(d['Height'])
			width = passSize(d['Width'])
			
			if length.to_f > 0
				cubic = 'Y'
			else
				cubic = 'N'
			end
			
			sampleLine = "661204,0000,#{d['Destination Rate Indicator']},#{@facilityZIP},#{@date},#{@time},#{pic},#{d['Destination ZIP Code']},#{mclass},Y,#{d['Rate Indicator']},#{weight},Y,#{length},#{height},#{width},00000,#{cubic},THDSN0,N"
			lines << sampleLine
		end
		passFile = File.open("#{$targetPath}\\Generated SBP Files\\TRP_P1SBP_OUT_#{@date}STC#{@stc}.pass", 'w')
		lines.each do |line|
			passFile.write("\n") if line != lines[0]
			passFile.write(line)
		end
		passSem = File.open("#{$targetPath}\\Generated SBP Files\\TRP_P1SBP_OUT_#{@date}STC#{@stc}.sem", 'w')
		passSem.close()
		puts "Built SBP PASS sample (.pass/.sem) for STC #{@stc}!"
	end
	#**********************************************
	#Re-format weight for PASS Files
	def passWeight(value)
		wholeNum = value[0, 4]
		decimal = value[5, 4]
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Re-format dimensions for PASS Files
	def passSize(value)
		wholeNum = value[1,2]
		decimal = value[3, 2]
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Builds out a POS Sample
	def buildPOS()
		first = true
		weight, length, height, width = '','','',''
		lines = pullLines()
		posFile = File.open("#{@fileName}_POS.dat", 'w')
		lines.each do |line|
			@allDetails.each do |detail|
				if line['Tracking Number'].include?(detail['Tracking Number'])
					weight = posWeight(detail['Weight'])
					length = posSize(detail['Length'])
					height = posSize(detail['Height'])
					width = posSize(detail['Width'])
					line['Weight'] = "\"#{weight}\""
					line['Length'] = "\"#{length}\""
					line['Height'] = "\"#{height}\""
					line['Width'] = "\"#{width}\""
					
					formattedLine = ''
					line.values.each do |val|
						formattedLine = formattedLine + "," + val if formattedLine.length > 0
						formattedLine = formattedLine + val if formattedLine.length == 0
					end
					posFile.write("\n") if not first
					posFile.write(formattedLine)
					first = false
				end
			end
		end
		posFile.close()
		posSem = File.open("#{@fileName}_POS.sem", 'w')
		posSem.close()
		puts "Built SBP POS sample (.dat/.sem) for STC #{@stc}!"
	end
	#*********************************************************************************************************************************
	#Pulls the detail records from an SBP file for SBP POS sample usage.
	def pullLines()
		detail = {}
		details = []
		count = 0
		file = File.open("#{@fileName}.dat", 'r') #Pull SBP File
		file.each_line do |line|
			array = line.chomp.split(',')
			@sbpFields.each_with_index do |field, i|
				detail.merge!(field => array[i]) if array[i] != nil
				detail.merge!(field => '') if array[i] == nil
			end
			details << detail.dup
			detail.clear()
		end
		file.close()
		return details
	end
	#*********************************************************************************************************************************
	#Re-format weight for POS Files
	def posWeight(value)
		wholeNum = value[0, 4]
		decimal = value[5, 4]
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Re-format dimensions for SBP POS Files
	def posSize(value)
		wholeNum = value[0,3] #Pulls the whole number portion of the eVS dimension/size convention
		decimal = value[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}".rjust(7, '0')
	end
	#*********************************************************************************************************************************
end

test = SBPGenerator.new()