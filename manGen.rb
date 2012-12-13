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
		@rateFile = 'rates.csv'  #To test current valid rate ingredients
		#@rateFile = 'oldrates.csv'  #To negative test invalid/removed rate ingredients...if activating, also activate @domClasses with BP
		@fileName = ''
		@rateIngredients = []
		@stcList = []
		@originZIP = '20260'  #Temporarily hard coded for simplicity.
		@facilityZIP = '20260'#Temporarily hard coded for simplicity.
		@recordCount = 0
		@time = Time.now.strftime('%H%M%S')
		@date = Time.now.strftime('%Y%m%d')
		#@date = '20121201'  #Temporarily hard coded to test pre-price change date.
		@permit = '33'		#Temporarily hard coded for simplicity.
		@permitZIP = '20260'#Temporarily hard coded for simplicity.
		@type = '1'
		@isDomestic = false
		@trim = ''
		
		@nsa = false
		
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
	def isNSA()
		puts "Do you want to generate this file for NSA rate purposes (y/n)? (Utilizes Custom Contracts, MID 911911911, PI 911)"
		prompt
		answer = gets.chomp.downcase
		if answer == 'y'
			puts "The generator will utilize the NSA mailer Custom Contracts (MID 911911911, PI 911)"
			@mid = '911911911'
			@permit = '911'
		else
			@mid = '990001337'
			@permit = '33'
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
			['BB','BL','BS','CM','EX','FC','LW','MR','PM','PS','RP','S2','SA'].include?(mail)
			#['BB','BL','BP','BS','CM','EX','FC','LW','MR','PM','PS','RP','S2','SA'].include?(mail) #Has invalid/removed mail classes for negative testing.
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
			return '01300' #13 inches (12x12x12 is minimum for DR/DN)
		elsif validVolumeRequired.include?(rateInd)
			minVol = 0.00
			maxVol = 12.00  #9.00 got up to Tier4...but no tier 5.  Upping to 12.00
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
			@fileName = "C:\\manifestgenerator\\generated files\\autogenerated_#{@mailClass}_#{@date}_RateTest"
		elsif @trim == 'f'
			@fileName = "C:\\manifestgenerator\\generated files\\autogenerated_#{@mailClass}_#{@date}_FeeTest"
		else
			@fileName = "C:\\manifestgenerator\\generated files\\autogenerated_#{@mailClass}_#{@date}#{@time}"
		end
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
			#baseline['Domestic Zone'] = zoneCalc(rate['Min Zone'], rate['Max Zone'])
			#baseline['Destination ZIP Code'] = validZIP(baseline['Domestic Zone'])
			#baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])
			
			rate.each do |key, val|
				baseline[key] = val if baseline.has_key?(key)
			end
			
			if @mailClass == 'MR' #Catches MR which has no STC combinations..
				baseline['Domestic Zone'] = zoneCalc(rate['Min Zone'], rate['Max Zone'])
				baseline['Destination ZIP Code'] = validZIP(baseline['Domestic Zone'])
				baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])
				baseline['Service Type Code'] = '???' #Need to figure out what the STC is for this...not in STC reference spreadsheet.
				baseline.each_value do |value|
					detail = detail + "#{value}|"
				end
				@recordCount = @recordCount + 1
				details << detail
				detail = ''
			elsif rate['Processing Category'] == 'O' #Catch Open & Distribute
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
					
					volCheck = volumeCheck(rate['Rate Indicator'])
					if volCheck != false
						baseline['Length'] = volCheck
						baseline['Width'] = volCheck
						baseline['Height'] = volCheck
					end
					
					baseline['Domestic Zone'] = zoneCalc(rate['Min Zone'], rate['Max Zone'])
					baseline['Destination ZIP Code'] = validZIP(baseline['Domestic Zone'])
					baseline['Weight'] = validWeight(rate['Min Weight'], rate['Max Weight'])
					
					baseline['Domestic Zone'] = '08' if rate['Rate Indicator'] == 'PM' #Catch Priority Mail 'PM' which requires ZIP starting in 963 = Zone 8.
					baseline['Destination ZIP Code'] = '96303' if rate['Rate Indicator'] == 'PM' #Assign 93603.
					
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
			puts "Built raw/cew/sem for mail class #{@mailClass}!"
		end
		details.clear
		sampleGen()
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
		puts "Enter 'r' to trim the build to only rate combinations, 'f' to trim to only fee combinations, or 'a' for all combinations."
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
			if @domClasses.include?(@mailClass) #Domestic
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
					#stuff
				when 'pos' #POS
					#stuff
				when 's' #STATS
					#stuff
				end
			elsif @intClasses.include?(@mailClass)
				buildIMD()
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
			if count > 0 and allDetails.size < 999
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
		details = pullDetails()
		numRecords = details.size.to_s.rjust(3, '0')
		imdFile = File.open("#{@fileName}_IMD.evs", 'w')
		imdHeader = ("eVS1H#{@facilityZIP}     5#{@date}THDSN0N#{numRecords}#{@mid}3.0     NN030").ljust(112, ' ')
		imdFile.write(imdHeader)
		
		details.each do |d| #d is each detail record in hash format
			pic = d['Tracking Number'].ljust(34, ' ')
			weight = weightReformat(d['Weight'])
			length = sizeReformat(d['Length'])
			height = sizeReformat(d['Height'])
			width = sizeReformat(d['Width'])
			girth = sizeReformat(d['Dimensional Weight'])
			zip = d['Destination ZIP Code'] if @domClasses.include?(d['Mail Class'])
			zip = '00000' if @intClasses.include?(d['Mail Class'])
			
			rateType = imdRate(d['Rate Indicator'])
			if rateType == 'shape'
				shape = d['Rate Indicator']
				sortation = 'NA'
			elsif rateType == 'sortation'
				sortation = d['Rate Indicator']
				shape = 'NA'
			else
				next
			end
			
			countryCode = '  ' if @domClasses.include?(d['Mail Class'])
			countryCode = d['Destination Country Code'] if @intClasses.include?(d['Mail Class'])
			
			sampleLine = "    D#{pic}#{weight}#{length}#{height}#{width}#{girth}#{zip}YN#{shape}#{d['Processing Category']}NNNNNNNNNNNN0.00000000#{d['Mail Class']}#{sortation}N     NA     NANNA#{' '.ljust(240, ' ')}#{countryCode}        #{Time.now.strftime('%m%d%Y')}#{@time}NNNNNNNNNN"
			imdFile.write("\n")
			imdFile.write(sampleLine)
		end
		imdSem = File.open("#{@fileName}_IMD.sem", 'w')
		puts "Built IMD sample (evs/sem) for #{@mailClass}!"
	end
	#*********************************************************************************************************************************
	#Determine IMD Rate Indicator
	def imdRate(rate)
		shapeFile = File.open('shapeIndicators.csv', 'r') #Get shape-based rate indicators
		shapes = shapeFile.gets.split(',')
		shapeFile.close()
		return 'shape' if shapes.include?(rate)
		
		sortationFile = File.open('sortationLevels.csv', 'r') #Get sortation levels
		sortations = sortationFile.gets.split(',')
		sortationFile.close()
		return 'sortation' if sortations.include?(rate)
	end
	#*********************************************************************************************************************************
	#Re-format weight for IMD Files
	def weightReformat(value)
		wholeNum = value[3, 2] #Pulls the 4th (X) and 5th (Y) digit from the format 000XYdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = value[5, 4]  #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Re-format dimensions for IMD Files
	def sizeReformat(value)
		wholeNum = value[0,3] #Pulls the whole number portion of the eVS dimension/size convention
		decimal = value[3, 2] #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}".ljust(7, '0')
	end
	#*********************************************************************************************************************************
	#Builds out a PASS File
	def buildPASS()
		imdFile = File.open("TRP_1EVS_OUT_#{@date}.pass", 'w')
		
		imdSem = File.open("TRP_1EVS_OUT_#{@date}.sem", 'w')
	end
	#*********************************************************************************************************************************
end

test = ManifestGenerator.new()