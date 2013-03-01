

class ModRate
	def initialize()
		puts "Initializing new rate csv file creation!"
		@rateFields = []
		@newRates = []
		
		processRates()
		newRateFile()
	end	
	#*********************************************************************************************************************************
	def processRates()
		eachRate = {}
		rateFile = File.open("C:\\manifestgenerator\\rates.csv", 'r')
		@rateFields = rateFile.readline.chomp.split(',')
		rateFile.each_line do |row|
			rate = row.chomp.split(',')
			@rateFields.each_with_index do |field, index|
				eachRate.merge!(field => rate[index])
			end
			
			arrayByZone = splitZones(eachRate)
			
			arrayByZone.each do |hash|
				#tempArray = splitWeights(hash)
				if ['BB', 'BL', 'BS', 'EX', 'PM', 'FC', 'PS', 'PG', 'LC', 'IE', 'CP'].include?(hash['Mail Class'])
					buildArray(splitWeights(hash))
				else
					@newRates << rate
				end
				#tempArray.each do |subHash|
				#	subHash.values.each do |val|
				#	@newRates << subHash.dup
				#end
			end
			eachRate.clear
		end
		rateFile.close()
	end
	#*********************************************************************************************************************************
	def splitZones(hash)
		allZones = []
		minZone = hash['Min Zone'].to_i
		maxZone = hash['Max Zone'].to_i
		hash.delete('Min Zone')
		hash.delete('Max Zone')
		
		while minZone <= maxZone
			hash.merge!('Zone' => minZone.to_s.rjust(2, '0'))
			allZones << hash.dup
			minZone = minZone + 1
		end
		
		return allZones
	end
	#*********************************************************************************************************************************
	#Mail Classes Rated by Zone and Weight
	#Mail Classes with Weight Affecting Postage: BB, BL, BS, EX, PM, FC, PS, PG, LC, IE, CP
	def splitWeights(hash)
		allWeights = []
		minWeight = hash.dup['Min Weight'].to_f
		maxWeight = hash.dup['Max Weight'].to_f
		x = minWeight
		newMin = 0.0
		newMax = 0.0
		
		while minWeight <= maxWeight
			newMin = minWeight if minWeight < 1
			newMin = newMax
			newMax = newMin + 1
			hash['Min Weight'] = newMin.to_s
			hash['Max Weight'] = newMax.to_s
			minWeight = minWeight + 1
			allWeights << hash.dup
			puts hash.dup
		end
		return allWeights
	end
	#*********************************************************************************************************************************
	def buildArray(arrayOfHashes)
		arrayOfHashes.each do |hash|
			line = ''
			count = 0
			hash.values.each do |val|
				line << "," if count > 0
				line << val
				count = count + 1
			end
			@newRates << line
		end
	end
	#*********************************************************************************************************************************
	def newRateFile()
		targetFile = File.open("C:\\manifestgenerator\\ratePrices.csv", 'w') #Opens new rate file.
		
		fields = ''
		fieldCount = 0
		@rateFields.each do |field|
			fields << "," if fieldCount > 0
			fields << field
			fieldCount = fieldCount + 1
		end
		targetFile.write(fields)
		
		@newRates.each do |line|
			targetFile.write("\n")
			targetFile.write(line)
		end
		
		targetFile.close()
		puts "Finished building new rate file."
	end
	#*********************************************************************************************************************************
end

test = ModRate.new()