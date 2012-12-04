#Manifest Generator Round 2

class ManifestGenerator
	def initialize()
		puts "Welcome to the eVS Manifest Generator!"

		@mid = '990001337' #Temporarily hard coded for simplicity.  If necessary, can use setMID() to add in the user prompt for a MID.
		@mailClasses = []
		@domClasses = []
		@intClasses = []
		@headerFields = []
		@detailFields = []
		@headerVals = {}
		@detailVals = {}
		@detailRecords = []
		@mailClass = ''
		@baselineFile = 'baseline.raw'
		@rateFile = 'rates.csv'
		@rateIngredients = []
		@stcList = []
		@originZIP = '20260'  #Temporarily hard coded for simplicity.
		@facilityZIP = '20260'#Temporarily hard coded for simplicity.
		@recordCount = 0
		@time = Time.now.strftime('%H%M%S')
		@date = Time.now.strftime('%Y%m%d')
		@permit = '33'		#Temporarily hard coded for simplicity.
		@permitZIP = '20260'#Temporarily hard coded for simplicity.
		@type = '1'
		@isDomestic = false
		@doTrim = false
		
		pullClasses('mailclasses.txt')
		pullHeaderFields('header.csv')
		pullDetailFields('detail.csv')
		baseline()
		setClass()
		fileGen() if @mailClass != 'ALL'
		buildAll() if @mailClass == 'ALL'
	end
	#*********************************************************************************************************************************
	def prompt()
		print "> "
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
	#Set Mail Class
	def setClass()
		puts "What mail class would you like to generate a file for?"
		prompt
		@mailClass = gets.upcase.chomp
		while @mailClasses.include?(@mailClass) == false and @mailClass != 'ALL'
			puts "That is not a valid mail class.  Please re-enter a mail class."
			prompt
			@mailClass = gets.upcase.chomp
		end
		puts "Mail Class #{@mailClass} selected."
		
		@isDomestic = true if @domClasses.include?(@mailClass)
	end
	#*********************************************************************************************************************************
	#Pull Mail Classes
	def pullClasses(filename)
		classList = File.open(filename)
		@mailClasses = classList.gets.split(',')
		classList.close()
		
		@domClasses = @mailClasses.dup
		@domClasses.keep_if do |mail|
			['BB','BL','BS','EX','FC','LW','MR','PM','PS','RP','S2','SA'].include?(mail)
		end
		
		@intClasses = @mailClasses.dup
		@intClasses.keep_if do |mail|
			['IE', 'LC', 'PG', 'CP'].include?(mail)
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
			#@detailRecords << @detailVals
			count = count + 1
		end
		file.close()
	end
	#*********************************************************************************************************************************
	#Pull Rates -- take (mailClass)
	def pullRates()
		eachRate = {}
		#rateFile = File.open("#{@mailClass}.csv", 'r')
		rateFile = File.open(@rateFile, 'r')
		fieldNames = rateFile.readline.chomp.split(',')
		rateFile.each_line do |row|
			rate = row.chomp.split(',')
			if rate.include?(@mailClass)
				fieldNames.each_with_index do |field, index|
					eachRate.merge!(field => rate[index])
				end
			end
			@rateIngredients << eachRate.dup if eachRate.empty? == false
			eachRate.clear
		end
		rateFile.close()
	end
	#*********************************************************************************************************************************
	#Pull STCs -- take (mailClass)
	def pullSTCs()
		eachSTC = {}
		stcFile = File.open('stcs.csv', 'r')
		fieldNames = stcFile.readline.chomp.split(',')
		stcFile.each_line do |row|
			stc = row.chomp.split(',')
			if stc.include?(@mailClass)
				fieldNames.each_with_index do |field, index|
					eachSTC.merge!(field => stc[index]) if stc[index] != nil
					eachSTC.merge!(field => '') if stc[index] == nil
				end
			end
			
			if @doTrim
				@stcList << eachSTC.dup if eachSTC['Service Type Code'] == getBaseSTC(@mailClass) and eachSTC.empty? == false
			else
				@stcList << eachSTC.dup if eachSTC.empty? == false
			end
			eachSTC.clear
		end
		stcFile.close()
	end
	#*********************************************************************************************************************************
	#Get Base STC -- provides the STC for the most basic STC combination
	def getBaseSTC(mailClass)
		baseSTCs = { 'BB' => '458', 'BL' => '582', 'BP' => '378', 'BS' => '521', 'CM' => '760', 'EX' => '710', 'FC' => '742', 'LW' => '789', 'PM' => '025', 'PS' => '642', 'RP' => '023', 'S2' => '703', 'SA' => '702' }
		return baseSTCs[mailClass]
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
		return "92750#{@mid}#{rand(99999999).to_s.rjust(8, '0')}"
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
		
		part = rand(min..max).round(1).to_s.split('.') #For simplicity, rounding to 1 decimal.  Can change round(#) up to 4 in the future if necessary.
		wholeNum = part[0].rjust(5,'0')
		decimal = part[1].ljust(4,'0')
		return wholeNum + decimal
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
	def filenameGen()
		return "C:\\manifestgenerator\\generated files\\autogenerated_#{@mailClass}_#{@date}#{@time}.raw"
	end
	#*********************************************************************************************************************************
	#Set File Type - set type based on the mail class.  Necessary to appropriately handle return-type products (MR and RP).
	def setFileType()
		if @mailClass == 'RP' or @mailClass == 'MR'
			@mid = '900484337'
			@permit = '151000'
			@permitZIP = '20260'
			@type = '3'
		else
			@mid = '990001337'
			@permit = '33'
			@permitZIP = '20260'
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
			
		@headerVals.each_value do |value|
			header = header + "#{value}|"
		end
		return header
	end
	#*********************************************************************************************************************************
	#Detail Generator >>>>>>>>>>>>>>>> WORK IN HOW TO HANDLE INTERNATIONAL MAIL CLASSES NEXT <<<<<<<<<<<<<<<<<<<<<<
	def detailGen()
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
		pullSTCs()
		baseline = @detailVals.dup
		detail = ''
		details = []
		@recordCount = 0
		
		@rateIngredients.each do |rate|
			baseline['Domestic Zone'] = zoneCalc(rate['Min Zone'], rate['Max Zone'])
			baseline['Destination ZIP Code'] = validZIP(baseline['Domestic Zone'])
			baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])
			
			rate.each do |key, val|
				baseline[key] = val if baseline.has_key?(key)
			end
			
			if @mailClass == 'MR' #Catches MR which has no STC combinations..
				baseline['Service Type Code'] = '???' #Need to figure out what the STC is for this...not in STC reference spreadsheet.
				baseline.each_value do |value|
					detail = detail + "#{value}|"
				end
				@recordCount = @recordCount + 1
				details << detail
				detail = ''
			else
				@stcList.each do |stc|
					stc.each do |stcKey, stcVal|
						baseline[stcKey] = stcVal if baseline.has_key?(stcKey)
						ins = insCheck(stcVal)
						baseline['Value of Article'] = ins if ins != false
						baseline['Tracking Number'] = picGen(stcVal) if stcKey == 'Service Type Code'
					end
				
					baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])
				
					baseline.each_value do |value|
						detail = detail + "#{value}|"
					end
					@recordCount = @recordCount + 1
					details << detail
					detail = ''
				end
			end
			baseline.clear
			baseline = @detailVals.dup
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
			@recordCount = @recordCount + 1
			details << detail
			detail = ''
		end
		baseline.clear
		baseline = @detailVals.dup
		return details
	end
	#*********************************************************************************************************************************
	#File Generator
	def fileGen()
		setFileType()
		file = File.open(filenameGen(), 'w')
		details = detailGen()
		file.write(headerGen())
		details.each do |line|
			file.write("\n")
			file.write(line)
		end
		details.clear
		file.close()
		puts "Built file for mail class #{@mailClass}!"
	end
	#*********************************************************************************************************************************
	#Handler for Mail Class 'ALL' to build all possible files
	def buildAll()
		trim()
		fileCount = 0
		totalCount = 0
		@mailClasses.each do |mailClass|
			@mailClass = mailClass
			@isDomestic = true if @domClasses.include?(@mailClass)
			@isDomestic = false if @intClasses.include?(@mailClass)
			fileGen()
			@rateIngredients.clear
			@stcList.clear
			fileCount = fileCount + 1
			totalCount = totalCount + @recordCount
			@recordCount = 0
		end
		puts "Finished building #{fileCount} files for a total of #{totalCount} unique detail records."
	end
	#*********************************************************************************************************************************
	#Determines whether a build includes all STC combinations, or only the base.
	def trim()
		puts "Enter 't' to trim the build to only the base STC or 'a' for all combinations."
		prompt
		input = gets.downcase.chomp
		while input != 't' and input != 'a'
			puts "#{input} is not a valid response, please select either 't' or 'a'."
			input = gets.downcase.chomp
		end
		@doTrim = true if input == 't'
		@doTrim = false if input == 'a'
	end
	#*********************************************************************************************************************************
end

test = ManifestGenerator.new()