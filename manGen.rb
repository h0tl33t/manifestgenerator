#Manifest Generator Round 2

require_relative 'rateCheck'

	#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	Dir.chdir($targetPath)
	if $targetPath != '.'
		Dir.mkdir("#{$targetPath}\\Generated Files\\") if File.directory?("#{$targetPath}\\Generated Files\\") != true
	end
	#*********************************************************************************************************************************
	
class ManifestGenerator
	def initialize()
		puts "Starting eVS file generation.."
		
		@mid = '990001337' #Temporarily hard coded for simplicity.  If necessary, can use setMID() to add in the user prompt for a MID.
		#@mid = '010101010' #Prod MID
		@mailClasses = []
		@domClasses = []
		@intClasses = []
		@headerFields = []
		@detailFields = []
		@headerVals = {}
		@detailVals = {}
		@detailRecords = []
		@mailClass = ''
		@baselineFile = "#{File.dirname(__FILE__)}\\baseline.raw"
		@stcs = "#{File.dirname(__FILE__)}\\stcs.csv"
		@rateFile = "#{File.dirname(__FILE__)}\\rates.csv"  #To test current valid rate ingredients
		#@rateFile = "#{File.dirname(__FILE__)}\\oldrates.csv"  #To negative test invalid/removed rate ingredients...if activating, also activate @domClasses with BP
		@fileName = ''
		@rateIngredients = []
		@stcList = []
		@originZIP = '20260'  #Temporarily hard coded for simplicity.
		@facilityZIP = '20260'#Temporarily hard coded for simplicity.
		@recordCount = 0
		@time = Time.now.strftime('%H%M%S')
		@date = Time.now.strftime('%Y%m%d')
		#@date = '20130113' #Temp test date.
		@permit = '33'		#Temporarily hard coded for simplicity.
		@permitZIP = '20260'#Temporarily hard coded for simplicity.
		#@permit = '123'		#Prod Permit
		#@permitZIP = '99999'#Prod Permit ZIP
		@type = '1'
		@isDomestic = false
		@trim = ''
		
		@nsa = false
		
		@rateCheck = RateCheck.new()
		
		pullClasses("#{File.dirname(__FILE__)}\\mailclasses.txt")
		pullHeaderFields("#{File.dirname(__FILE__)}\\header.csv")
		pullDetailFields("#{File.dirname(__FILE__)}\\detail.csv")
		baseline()
		setClass()
		fileGen() if @mailClass != 'ALL'
		buildAll() if @mailClass == 'ALL'
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
		puts "	Options are: #{@mailClasses}"
		puts "	(or type 'all' to build a manifest for each of the mail classes at once)"
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
			['BB','BL','BS','CM','EX','FC','LW','PM','PS','RP','S2','SA'].include?(mail)
			#['BB','BL','BP','BS','CM','EX','FC','LW','PM','PS','RP','S2','SA'].include?(mail) #Has invalid/removed mail classes for negative testing.
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
			
			if @trim == 'f' #Only include the first rate.
				@rateIngredients << eachRate.dup if rateCount ==1 and eachRate.empty? == false
			else
				@rateIngredients << eachRate.dup if eachRate.empty? == false
			end
			eachRate.clear
		end
		rateFile.close()
	end
	#*********************************************************************************************************************************
	#Pull STCs -- take (mailClass)
	def pullSTCs()
		eachSTC = {}
		stcFile = File.open(@stcs, 'r')
		fieldNames = stcFile.readline.chomp.split(',')
		stcFile.each_line do |row|
			stc = row.chomp.split(',')
			if stc.include?(@mailClass)
				fieldNames.each_with_index do |field, index|
					eachSTC.merge!(field => stc[index]) if stc[index] != nil
					eachSTC.merge!(field => '') if stc[index] == nil
				end
			end
			
			if @trim == 'r' #Only include a single base STC(from getBaseSTC) 
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
	def filenameGen()
		if @trim == 'r'
			#@fileName = "C:\\manifestgenerator\\generated files\\autogenerated_#{@mailClass}_#{@date}_RateTest"
			#@fileName = File.expand_path("..\\Generated Files\\autogenerated_#{@mailClass}_#{@date}_RateTest", __FILE__)
			@fileName = "#{$targetPath}\\Generated Files\\autogenerated_#{@mailClass}_#{@date}_RateTest"
		elsif @trim == 'f'
			#@fileName = "C:\\manifestgenerator\\generated files\\autogenerated_#{@mailClass}_#{@date}_FeeTest"
			#@fileName = File.expand_path("..\\Generated Files\\autogenerated_#{@mailClass}_#{@date}_FeeTest", __FILE__)
			@fileName = "#{$targetPath}\\Generated Files\\autogenerated_#{@mailClass}_#{@date}_FeeTest"
		else
			#@fileName = "C:\\manifestgenerator\\generated files\\autogenerated_#{@mailClass}_#{@date}#{@time}"
			#@fileName = File.expand_path("..\\Generated Files\\autogenerated_#{@mailClass}_#{@date}#{@time}", __FILE__)
			@fileName = "#{$targetPath}\\Generated Files\\autogenerated_#{@mailClass}_#{@date}#{@time}"
		end
	end
	#*********************************************************************************************************************************
	#Set File Type - set type based on the mail class.  Necessary to appropriately handle return-type products (MR and RP).
	def setFileType()
		if @mailClass == 'RP'
			@mid = '900484337'
			@permit = '151001'
			@permitZIP = '20260'
			@type = '3'
			
			#@mid = '020202020'	#Prod PRS
			#@permit = '12866001'#Prod PRS
			#@permitZIP = '99999'#Prod PRS
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
		
		@rateCheck.grabEFN(@headerVals['Electronic File Number'])
			
		@headerVals.each_value do |value|
			header = header + "#{value}|"
		end
		return header
	end
	#*********************************************************************************************************************************
	#Detail Generator
	def detailGen()
		isNSA() if @nsa == false #Checks to see if user wants to utilize NSA mailer information or not.  Only runs once according to @nsa.
		
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
			rate.each do |key, val|
				baseline[key] = val if baseline.has_key?(key)
			end
			
			if rate['Processing Category'] == 'O' #Catch Open & Distribute
				#nsaOnly = ['O5', 'O6', 'O7'] #For potential future use.
				#next if ['O5', 'O6', 'O7'].include?(rate['Rate Indicator']) #Catch NSA Only O&D Rates and temporarily skip over these rates
				baseline['Open and Distribute Contents Indicator'] = 'EP' #Required field for O&D, EP = Parcels/Electronic Payment
				baseline['Destination Facility Type'] = rate['Destination Rate Indicator']
				baseline['Domestic Zone'] = zoneCalc(rate['Min Zone'], rate['Max Zone'])
				baseline['Destination ZIP Code'] = validZIP(baseline['Domestic Zone'])
				baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])
				if @mailClass == 'PM'
					pmod1 = '123' #Priority Mail Open & Distribute STC Value
					pmod2 = '430' #Priority Mail Open & Distribute 1st Service Code
					baseline['Service Type Code'] = pmod1
					baseline['Extra Service Code 1st Service'] = pmod2
					baseline['Tracking Number'] = picGen(pmod1)
				elsif @mailClass == 'EX'
					exod = '723' #Express Mail Open & Distribute STC Value
					baseline['Service Type Code'] = exod
					baseline['Tracking Number'] = picGen(exod)
					baseline['Delivery Option Indicator'] = 'E' #Required for EXOD
				end
				baseline.each_value do |value|
					detail = detail + "#{value}|"
				end
				@rateCheck.check(baseline)
				@recordCount = @recordCount + 1
				details << detail
				detail = ''
			else
				@stcList.each do |stc|
					stc.each do |stcKey, stcVal|
						baseline[stcKey] = stcVal if baseline.has_key?(stcKey)
						ins = insCheck(stcVal)
						baseline['Value of Article'] = ins if ins != false
						baseline['COD Amount Due Sender'] = '0005000' if stcVal == '915' #If COD STC, fill COD Amount Due Sender to $50
						baseline['Tracking Number'] = picGen(stcVal) if stcKey == 'Service Type Code'
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
			
			@rateCheck.check(baseline)
			@recordCount = @recordCount + 1
			details << detail
			detail = ''
		end
		baseline.clear
		baseline = @detailVals.dup
		return details
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
	#File Generator
	def fileGen()
		trim()
		setFileType()
		filenameGen()
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
			puts "Built manifest (.raw/.cew/.sem) for mail class #{@mailClass}!"
		end
		details.clear
		sampleGen()
	end
	#*********************************************************************************************************************************
	#Handler for Mail Class 'ALL' to build all possible files
	def buildAll()
		#trim() Moved to fileGen (will give trim options for each single build)
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
		puts "Enter 'r' to trim the build to only rate combinations, 'f' to trim to only fee combinations, or 'a' for all combinations."
		puts "	'r' will iterate through all valid rates."
		puts "	'f' will take the first valid rate, then iterate through all valid fee combinations using that rate."
		puts "	'a' will iterate through all fee combinations for every valid rate."
		prompt
		@trim = gets.downcase.chomp
		while @trim != 'r' and @trim != 'f' and @trim != 'a'
			puts "#{@trim} is not a valid response, please select either 'r', 'f', or 'a'."
			prompt
			@trim = gets.downcase.chomp
		end
	end
	#*********************************************************************************************************************************
	#Handler for Sample Building
	def sampleGen()
		puts "Enter 's' to generate a sample for this file.  (Anything else to continue without building a sample.)"
		prompt
		input = gets.downcase.chomp
		if input == 's'
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
	#Pulls the detail records for sample usage.
	def pullDetails()
		detail = {}
		allDetails = []
		count = 0
		file = File.open("#{@fileName}.raw", 'r')
		file.each_line do |line|
			array = line.chomp.split('|')
			if count > 0
				@detailFields.each_with_index do |field, i|
					detail.merge!(field => array[i]) if array[i] != nil
					detail.merge!(field => '') if array[i] == nil
				end
				allDetails << detail.dup if detail['Barcode'] == '1'
				detail.clear()
			end
			count = count + 1
		end
		file.close()
		return allDetails
	end
	#*********************************************************************************************************************************
	#Builds out an IMD File
	def buildIMD()
		#DDU = D, SCF = S, NDC = B, ASF = F, None = N
		facilityTypes = {'D' => '1', 'S' => '2', 'B' => '3', 'F' => '4', 'N' => '5'} 
		details = pullDetails()
		lines = []
		sampleCount = 0
		facilityTypes.keys.each do |dri|
			details.each do |d|
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
				imdFile = File.open("#{@fileName}_IMD_#{dri}.evs", 'w')
				imdHeader = ("eVS1H#{@facilityZIP}     #{facilityTypes[dri]}#{Time.now.strftime("%m%d%Y")}THDSN0  N#{numRecords}#{@mid}3.0     NN030").ljust(112, ' ')
				#imdHeader = ("eVS1H#{@facilityZIP}     #{facilityTypes[dri]}01132013THDSN0  N#{numRecords}#{@mid}3.0     NN030").ljust(112, ' ') #Hard-coded date for date-sensitive testing.
				imdFile.write(imdHeader)
				lines.each do |line|
					imdFile.write("\n")
					imdFile.write(line)
				end
				imdFile.close()
				imdSem = File.open("#{@fileName}_IMD_#{dri}.sem", 'w')
				imdSem.close()
				lines.clear()
				sampleCount = 0
				puts "Built IMD sample (.evs/.sem) for #{@mailClass} and Facility Type #{dri}!"
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
		wholeNum = value[3, 2] #Pulls the 4th (X) and 5th (Y) digit from the format 000XYdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = value[5, 4]  #Pulls the decimal portion
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
		pounds = value[2, 3] #Pulls the 3rd (X), 4th (Y) and 5th (Z) digit from the format 00XYZdddd where 'd' is the decimal portion of the eVS weight convention
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
		details = pullDetails()
		count = 0
		mclass = ''
		
		details.each do |d| #d is each detail record in hash format
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
		statsFile = File.open("#{$targetPath}\\Generated Files\\STATS_#{@date}#{@time}#{mclass}.DAT", 'w')
		lines.each do |line|
			statsFile.write("\n") if line != lines[0]
			statsFile.write(line)
		end
		statsSem = File.open("#{$targetPath}\\Generated Files\\STATS_#{@date}#{@time}#{mclass}.sem", 'w')
		statsSem.close()
		puts "Built STATS sample (.DAT/.sem) for #{@mailClass}!"
	end
	#*********************************************************************************************************************************
	#Builds out a STATS File Version 1
	def buildSTATS()
		lines = []
		details = pullDetails()
		count = 0
		mclass = ''
		
		details.each do |d| #d is each detail record in hash format
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
			
			sampleLine = "#{@date}5405315#{count.to_s.rjust(4, ' ')}#{pounds}#{ounces}   1#{classInfo}#{shape}K000#{length}#{height}#{width}0100#{@originZIP}#{pic}0#{@mid}#{zip}01THDSN0#{@date}000000   0"
			lines << sampleLine
		end
		statsFile = File.open("#{$targetPath}\\Generated Files\\STATS_#{@date}#{@time}#{mclass}.DAT", 'w')
		lines.each do |line|
			statsFile.write("\n") if line != lines[0]
			statsFile.write(line)
		end
		statsSem = File.open("#{$targetPath}\\Generated Files\\STATS_#{@date}#{@time}#{mclass}.sem", 'w')
		statsSem.close()
		puts "Built STATS sample (.DAT/.sem) for #{@mailClass}!"
	end
	#**********************************************
	#Builds out a PASS Sample
	def buildPASS()
		lines = []
		details = pullDetails()
		count = 0
		mclass = ''
		
		details.each do |d| #d is each detail record in hash format
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
		passFile = File.open("#{$targetPath}\\Generated Files\\TRP_P1EVS_OUT_#{@date}#{mclass}.pass", 'w')
		lines.each do |line|
			passFile.write("\n") if line != lines[0]
			passFile.write(line)
		end
		passSem = File.open("#{$targetPath}\\Generated Files\\TRP_P1EVS_OUT_#{@date}#{mclass}.sem", 'w')
		passSem.close()
		puts "Built PASS sample (.pass/.sem) for #{@mailClass}!"
	end
	#**********************************************
	#Re-format weight for PASS Files
	def passWeight(value)
		wholeNum = value[1, 4] #Pulls the 2nd (A), 3rd (B), 4th (C) and 5th (D) digit from the format 0ABCDdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = value[5, 4]  #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Re-format dimensions for PASS Files
	def passSize(value)
		wholeNum = value[1,2] #Pulls the whole number portion from 00 to 99 of the eVS dimension/size convention
		decimal = value[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Builds out a POS Sample
	def buildPOS()
		lines = []
		details = pullDetails()
		count = 0
		mclass = ''
		
		details.each do |d| #d is each detail record in hash format
			count = count + 1
			mclass = d['Mail Class']
			pic = d['Tracking Number'].ljust(34, ' ')
			weight = posWeight(d['Weight'])
				
			sampleLine = "#{pic},#{@date},#{weight},#{d['Destination ZIP Code']},THDSN0"
			lines << sampleLine
		end
		posFile = File.open("#{$targetPath}\\Generated Files\\TRP_P1PRS_OUT_#{@date}#{mclass}.pos", 'w')
		lines.each do |line|
			posFile.write("\n") if line != lines[0]
			posFile.write(line)
		end
		posFile.close()
		posSem = File.open("#{$targetPath}\\Generated Files\\TRP_P1PRS_OUT_#{@date}#{mclass}.sem", 'w')
		posSem.close()
		puts "Built POS sample (.pos/.sem) for #{@mailClass}!"
	end
	#**********************************************
	#Re-format weight for POS Files
	def posWeight(value)
		wholeNum = value[1, 4] #Pulls the 2nd (A), 3rd (B), 4th (C) and 5th (D) digit from the format 0ABCDdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = value[5, 4]  #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
end

test = ManifestGenerator.new()