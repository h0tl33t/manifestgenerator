#The validateRates.rb program takes the output from rateCheck.rb and compares the expected rate against postage contained in
#an EVS Variance Report (in .csv).  The program logs whether or not each rate comparison matched or mismatched.
#Assumptions:
#	1) ValidateRates.exe is stored and run from the same folder as ManifestGenerator.exe.
#	2) User/QTP knows the EFN of the file to be validated.
#	3) User/QTP stores the variance file in the format [EFN]_variance# where '#' starts at 1 and increases for each variance generated by a single EFN
#	4) User/QTP stores the reconciled sample report in the format ReconciledReport(Mon-YYYY).csv where 'Mon' is the first 3-letters of the month the report is from.
#	5) The rateCheck, variance, and reconciled sample report files are stored in .csv in the child folder '/ref/' from the parent directory where ValidateRates.exe is stored and run.

	#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	Dir.chdir($targetPath)
	#*********************************************************************************************************************************

require 'benchmark'

class RateValidate
	#*********************************************************************************************************************************
	def initialize()
		puts "Starting EVS rate validation.."
		@workPath = "#{File.expand_path($targetPath)}/ref"
		@month = getMonth(Time.now.month)
		@year = Time.now.year.to_s
		
		#Clear existing files (necessary because log methods utilize 'a' write process)
		File.delete("#{@workPath}/#{@efn}_validationResults.csv") if File.exists?("#{@workPath}/#{@efn}_validationResults.csv")
		#File.delete("#{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv") if File.exists?("#{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv")
		
		#sampleFile = checkSample()
		
		@efn = ''
		efns = getEFN()
		if efns != nil
			efns.each do |eachEFN| #Set EFN and compare for each EFN/rateCheck file in /ref/
				@efn = eachEFN
				compare()
				#compareSample(sampleFile) if sampleFile != ''
				puts "Validation results generated and stored in #{@workPath}/#{@efn}_validationResults.csv!" if File.exists?("#{@workPath}/#{@efn}_validationResults.csv")
				puts "Generation of #{@workPath}/#{@efn}_validationResults.csv failed.." if not File.exists?("#{@workPath}/#{@efn}_validationResults.csv")
			end
			#puts "Validation results generated and stored in #{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv!" if File.exists?("#{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv")
			#puts "Generation of #{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv failed.." if not File.exists?("#{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv")
		end
		puts "Press any key to exit the program."
		stop = gets.chomp
	end
	#*********************************************************************************************************************************
	def prompt()
		print "> "
	end
	#*********************************************************************************************************************************
	def getEFN()
		efns = [] #Array to hold all EFNs to validate.
		bothFilesExist = false
		
		puts "Type 'auto' to automatically search #{@workPath}/ for Rate Check files ([efn]_rateCheckXX.csv).."
		puts "Or enter an EFN (EX: 9275099000133713459730) to validate:"
		prompt
		efn = gets.chomp
		
		while efn.length != 22 and efn.downcase != 'auto'
			puts "#{efn} is not a valid 22-digit EFN or 'auto'.  Please re-enter a valid value (EFN or 'auto'):"
			prompt
			efn = gets.chomp
		end
		
		if efn.downcase == 'auto'
				rateCheckFiles = Dir.glob("#{@workPath}/*_rateCheck??.csv")
				rateCheckFiles.each do |checkFile|
					efns << (/\d{22}/.match(checkFile)).to_s #Pulls a 22-digit EFN from the filename then coverts the MatchData object to a string.
				end
				
				varianceFiles = Dir.glob("#{@workPath}/*_variance*")
				varianceFiles.each do |varFile|
					bothFilesExist = true if efns.include?((/\d{22}/.match(varFile)).to_s)
				end
				
				if bothFilesExist
					puts "EFNs collected: #{efns}"
				else
					puts "Error encountered.  Verify the following:"
					puts "1) Both the Rate Check and Variance files are in the correct location (#{@workPath}/)."
					puts "2) Rate Check file(s) follow naming convention - [EFN]_rateCheckXX.csv where 'XX' is the 2-character mail class code."
					puts "3) Variance file(s) follow naming convention -  [EFN]_variance#.csv where '#' starts at 1 and increases for each variance generated by a single EFN."
					return nil
				end
		else
			efns << efn
		end
		return efns
	end
	#*********************************************************************************************************************************
	def compare()
		rateCheck = loadFile('Rate Check')
		variance = loadFile('Variance')
		matchedTier = ''
		matched = false
		comparedRecords = []
		Benchmark.bm do |bench|
		bench.report {
		#Have to iterate over two arrays full of hashes, which can get slow when the arrays grow in size.  Once hashes have been matched up from each array, delete them since we aren't using them for anything else.
		variance.each_with_index do |varRecord, varianceIndex|
			checkRecord = rateCheck.find {|check| check['Tracking Number'] == varRecord['PIC']}
			matchedTier, matched = "Base Rate", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Base Rate'].to_f.round(2)
			matchedTier, matched = "Plus Rate", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Plus Rate'].to_f.round(2)
			matchedTier, matched = "both Base and Plus Rates", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Base Rate'].to_f.round(2) and varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Plus Rate'].to_f.round(2)
			comparedRecords << ["'#{varRecord['PIC']}'", varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], checkRecord['Zone'], varRecord['eVS Zone'], checkRecord['Base Rate'], checkRecord['Plus Rate'], varRecord['eVS Postage + Surch ($)'], "Validated at #{matchedTier}"] if matched
			comparedRecords << ["'#{varRecord['PIC']}'", varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], checkRecord['Zone'], varRecord['eVS Zone'], checkRecord['Base Rate'], checkRecord['Plus Rate'], varRecord['eVS Postage + Surch ($)'], "Matching rate not found."] unless matched
			matched = false
			checkRecord.clear
=begin
			rateCheck.each_with_index do |checkRecord, rateIndex|
				if varRecord['PIC'].delete("'") == checkRecord['Tracking Number'].delete("'") #Some PICs/Tracking Numbers do not contain ' while others do.  To establish a base, delete all '
					matchedTier, matched = "Base Rate", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Base Rate'].to_f.round(2)
					matchedTier, matched = "Plus Rate", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Plus Rate'].to_f.round(2)
					matchedTier, matched = "both Base and Plus Rates", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Base Rate'].to_f.round(2) and varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Plus Rate'].to_f.round(2)
					#logResults(varRecord['PIC'], varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], varRecord['eVS Zone'], varRecord['eVS Postage + Surch ($)'], "Validated at #{matchedTier}") if matched
					#logResults(varRecord['PIC'], varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], varRecord['eVS Zone'], varRecord['eVS Postage + Surch ($)'], "Matching rate not found.") unless matched
					comparedRecords << [varRecord['PIC'], varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], checkRecord['Zone'], varRecord['eVS Zone'], checkRecord['Base Rate'], checkRecord['Plus Rate'], varRecord['eVS Postage + Surch ($)'], "Validated at #{matchedTier}"] if matched
					comparedRecords << [varRecord['PIC'], varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], checkRecord['Zone'], varRecord['eVS Zone'], checkRecord['Base Rate'], checkRecord['Plus Rate'], varRecord['eVS Postage + Surch ($)'], "Matching rate not found."] unless matched
					variance.delete_at(varianceIndex)
					rateCheck.delete_at(rateIndex)
					puts "Variance Size: #{variance.length}"
					puts "RateCheck Size: #{rateCheck.length}"
					puts "***********************"
					break
				end
				matched = false
				#puts "Variance Size: #{variance.length}"
				#puts "RateCheck Size: #{rateCheck.length}"
				#puts "***********************"
			end
=end
		end
		sortedData = comparedRecords.sort_by {|array| array[3]} #Sort by varRecord['Rate'] which is index 3 in each array inside of comparedRecords array
		logResults(sortedData)
		}
		end
	end
	#*********************************************************************************************************************************
	def compareSample(fileName)
		sampleReport = loadFile('Sample', fileName)
		variance = loadFile('Variance')

		sampleReport.each do |sampleRecord|
			variance.each do |varRecord|
				if varRecord['PIC'].include?(sampleRecord['Package Identification Code (PIC)'][1..-1])
					vRate = varRecord['eVS Postage + Surch ($)'].to_f.round(2)
					sRate = sampleRecord['Sample Postage ($)'].to_f.round(2)
					result = "Matched" if sRate == vRate
					result = "Rates not matched" if sRate != vRate
					logSampleResults(varRecord['PIC'], sampleRecord['Sample Source'], sampleRecord['Mail Class'], vRate, sRate, result)
				end
			end
		end
	end
	#*********************************************************************************************************************************
	def checkSample()		
		puts "Checking for Reconciled Sample Reports to validate.."
		sampleReports = Dir.glob("#{@workPath}/ReconciledReport*.csv") #Reconciled Sample Report Format: ReconciledReport(Mar-2013).csv
		if sampleReports.size > 0
			sampleReports.each_with_index do |report, index|
				/\((?<m>\w*)\-(?<y>\d*)\)/ =~ report
				if m.include?(@month) and y.include?(@year)
					puts "Found report for current month (#{m} #{y}) - enter 'y' to validate (any other key to continue without)"
					prompt
					if gets.chomp.downcase == 'y'
						puts "Will validate postage found in the variance reports against #{report}."
						return report
					else
						return ''
					end
				else
					puts "Found old data (will not validate) for #{m} #{y}."
				end
			end
			return ''
		else
			puts "No Reconciled Sample Reports found to validate."
			return ''
		end
	end
	#*********************************************************************************************************************************
	def loadFile(*param) #param[0] is type with expected values 'Rate Check', 'Variance', and 'Sample'. param[1] is a file name (used to pass in sampling report for current month)
		fileNames = [] #Will hold all file names to load.
		detailRecords = []
		detailRow = {}
		
		fileNames = Dir.glob("#{@workPath}/#{@efn}_rateCheck??.csv") if param[0] == 'Rate Check' #Should only add 1 file name to the array fileName.
		fileNames = Dir.glob("#{@workPath}/#{@efn}_variance*.csv") if param[0] == 'Variance' #Dir.glob returns an array of all matching files..can be more than 1.
		fileNames << param[1] if param[0] == 'Sample'
		puts "Loading #{param[0]} file(s):"
		fileNames.each_with_index {|file, i| puts "#{(i.to_i + 1)}) #{file}"}
		
		fileNames.each do |eachFile|
			file = File.open(eachFile,'r')
			fieldNames = file.readline.chomp.split(',')
			file.each_line do |line|
				detail = line.chomp.split(',')
				fieldNames.each_with_index do |name, index|
					detailRow.merge!(name.to_s => detail[index].to_s)
					detailRow['PIC'] = "#{detailRow['PIC']}".delete("'") if param[0] == 'Variance'
					detailRow['Tracking Number'] = "#{detailRow['Tracking Number']}".delete("'") if param[0] == 'Rate Check'
				end
				detailRecords << detailRow.dup if detailRow.empty? == false
				detailRow.clear
			end
			file.close()
		end
		return detailRecords.sort_by {|hash| hash['Tracking Number']} if param[0] == 'Rate Check'
		return detailRecords.sort_by {|hash| hash['PIC']} if param[0] == 'Variance'
	end
	#*********************************************************************************************************************************
	def sortFile(hashArray) #Takes output from loadFile (an array of hashes)
		
	end
	#*********************************************************************************************************************************
	def getMonth(number)
		months = {1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr', 5 => 'May', 6 => 'Jun', 7 => 'Jul', 8 => 'Aug', 9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec'}
		return months[number]
	end
	#*********************************************************************************************************************************
=begin	
	def logResults(pic, mc, pc, ri, dri, weight, zone, rate, result)
		log = File.open("#{@workPath}/#{@efn}_validationResults.csv",'a')
		log.write("Tracking Number,Mail Class,Processing Category,Rate Indicator,Destination Rate Indicator,Weight,Zone,Rate Validated,Validation Result") if File.zero?("#{@workPath}/#{@efn}_validationResults.csv")
		log.write("\n")
		log.write("#{pic},#{mc},#{pc},#{ri},#{dri},#{weight},#{zone},#{rate},#{result}")
		log.close()
	end
=end
	#*********************************************************************************************************************************
	def logResults(results) #Where results is a 2-dimensional array (array of arrays) with each sub-array representing a single line of results
		log = File.open("#{@workPath}/#{@efn}_validationResults.csv",'a')
		log.write("Tracking Number,Mail Class,Processing Category,Rate Indicator,Destination Rate Indicator,Weight,Manifest Zone,EVS Zone,Base Rate,Plus Rate,Variance Rate,Validation Result")
		results.each do |line|
			line = line.join(",")
			log.write("\n")
			log.write(line)
		end
		log.close()
	end
	#*********************************************************************************************************************************
	def logSampleResults(pic, type, mc, vRate, sRate, result)
		typeNames = {'I' => 'IMD', 'S' => 'STATS', 'P' => 'PASS', 'O' => 'POS'}
		log = File.open("#{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv",'a')
		log.write("Package Indentification Code (PIC),Sample Type,Mail Class,Manifest Rate,Sample Rate,Result") if File.zero?("#{@workPath}/sampleValidationResults(#{@month}-#{@year}).csv")
		log.write("\n")
		log.write("#{pic},#{typeNames[type]},#{mc},#{vRate},#{sRate},#{result}")
		log.close()
	end
	#*********************************************************************************************************************************
end

test = RateValidate.new()