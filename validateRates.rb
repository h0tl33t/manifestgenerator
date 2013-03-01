#The validateRates.rb program takes the output from rateCheck.rb and compares the expected rate against postage contained in
#an EVS Variance Report (in .csv).  The program logs whether or not each rate comparison matched or mismatched.
#Assumptions:
#	1) ValidateRates.exe is stored and run from the same folder as ManifestGenerator.exe.
#	2) User/QTP knows the EFN of the file to be validated.
#	3) User/QTP stores the variance file in the format [EFN]_variance# where '#' starts at 1 and increases for each variance generated by a single EFN
#	4) The rateCheck and variance files are stored in .csv in the child folder '/ref/' from the parent directory where ValidateRates.exe is stored and run.

	#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	Dir.chdir($targetPath)
	#*********************************************************************************************************************************

class RateValidate
	#*********************************************************************************************************************************
	def initialize()
		puts "Welcome to the EVS Rate Validator!"
		@workPath = "#{File.expand_path($targetPath)}/ref"
		@efn = ''
		efns = getEFN()
		efns.each do |eachEFN| #Set EFN and compare for each EFN/rateCheck file in /ref/
			@efn = eachEFN
			File.delete("#{@workPath}/#{@efn}_validationResults.csv") if File.exists?("#{@workPath}/#{@efn}_validationResults.csv")
			compare()
			puts "Validation results generated and stored in #{@workPath}/#{@efn}_validationResults.csv!"
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
					puts "Rate Check Files Detected: #{rateCheckFiles}"
					puts "Variance Files Detected: #{varianceFiles}"
				else
					puts "Error encountered.  Verify the following:"
					puts "1) Both the Rate Check and Variance files are in the correct location (#{@workPath}/)."
					puts "2) Rate Check file(s) follow naming convention - [EFN]_rateCheckXX.csv where 'XX' is the 2-character mail class code."
					puts "3) Variance file(s) follow naming convention -  [EFN]_variance#.csv where '#' starts at 1 and increases for each variance generated by a single EFN."
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
		
		variance.each do |varRecord|
			rateCheck.each do |checkRecord|
				if varRecord['PIC'] == checkRecord['Tracking Number']
					matchedTier, matched = "Base Rate", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Base Rate'].to_f.round(2)
					matchedTier, matched = "Plus Rate", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Plus Rate'].to_f.round(2)
					matchedTier, matched = "both Base and Plus Rates", true if varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Base Rate'].to_f.round(2) and varRecord['eVS Postage + Surch ($)'].to_f.round(2) == checkRecord['Plus Rate'].to_f.round(2)
					logResults(varRecord['PIC'], varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], varRecord['eVS Zone'], varRecord['eVS Postage + Surch ($)'], "Validated at #{matchedTier}") if matched
					logResults(varRecord['PIC'], varRecord['Mail Class'], checkRecord['PC'], varRecord['Rate'], varRecord['Dest Rate'], varRecord['Weight'], varRecord['eVS Zone'], varRecord['eVS Postage + Surch ($)'], "Matching rate not found.") if not matched
				end
			end
		end
	end
	#*********************************************************************************************************************************
	def loadFile(type)
		fileNames = [] #Will hold all file names to load.
		detailRecords = []
		detailRow = {}
		
		fileNames = Dir.glob("#{@workPath}/#{@efn}_rateCheck??.csv") if type == 'Rate Check' #Should only add 1 file name to the array fileName.
		fileNames = Dir.glob("#{@workPath}/#{@efn}_variance*.csv") if type == 'Variance' #Dir.glob returns an array of all matching files..can be more than 1.
		puts "Loading #{type} file(s): #{fileNames}"
		
		fileNames.each do |eachFile|
			file = File.open(eachFile,'r')
			fieldNames = file.readline.chomp.split(',')
			file.each_line do |line|
				detail = line.chomp.split(',')
				fieldNames.each_with_index do |name, index|
					detailRow.merge!(name.to_s => detail[index].to_s)
				end
				detailRecords << detailRow.dup if detailRow.empty? == false
				detailRow.clear
			end
			file.close()
		end
		return detailRecords
	end
	#*********************************************************************************************************************************
	def logResults(pic, mc, pc, ri, dri, weight, zone, rate, result)
		log = File.open("#{@workPath}/#{@efn}_validationResults.csv",'a')
		log.write("Tracking Number,Mail Class,Processing Category,Rate Indicator,Destination Rate Indicator,Weight,Zone,Rate Validated,Validation Result") if File.zero?("#{@workPath}/#{@efn}_validationResults.csv")
		log.write("\n")
		log.write("#{pic},#{mc},#{pc},#{ri},#{dri},#{weight},#{zone},#{rate},#{result}")
		log.close()
	end
	#*********************************************************************************************************************************
end

test = RateValidate.new()