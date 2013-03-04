#The rateCheck.rb program is designed to link into manGen.rb (EVS Manifest Generator) to calculate expected rates detail-by-detail
#record.  The resulting [EFN].csv files are then used by another program to validate postage from variance reports in .csv.

	#Set necessary variables to allow for OCRA Executable to function on ACE Machines ************************************************
	$targetPath = File.dirname(ENV['OCRA_EXECUTABLE'].to_s)
	Dir.chdir($targetPath)
	#*********************************************************************************************************************************
	
class RateCheck
	#*********************************************************************************************************************************
	def initialize()
		@rateLocation = "#{File.dirname(__FILE__)}\\rateTables\\"
		Dir.mkdir("#{$targetPath}\\ref\\") if File.directory?("#{$targetPath}\\ref\\") != true
		@mailClass = ''
	end
	#*********************************************************************************************************************************
	def check(detailRecord)
		@mailClass = detailRecord['Mail Class'] #Used for grabEFN()
		if detailRecord.class.to_s != "Hash"
			put "Detail Record parameter is not the expected hash, it is a #{detailRecord.class.to_s}!"
		else
			file = File.open("#{$targetPath}/ref/TEMP_rateCheck#{detailRecord['Mail Class']}.csv",'a')
			#file.write("Tracking Number, Base Rate, Plus Rate") if File.zero?("#{$targetPath}/ref/TEMP_rateCheck#{detailRecord['Mail Class']}.csv")
			file.write("Tracking Number,PC,RI,DRI,Length,Height,Width,Weight,Zone,Base Rate,Plus Rate") if File.zero?("#{$targetPath}/ref/TEMP_rateCheck#{detailRecord['Mail Class']}.csv")
			
			case detailRecord["Mail Class"]
			when "BB"
				baseRate = findRateBB(detailRecord)
				plusRate = ''
			when "BS"
				baseRate = findRateBS(detailRecord)
				plusRate = ''
			when "BL"
				baseRate = findRateBL(detailRecord)
				plusRate = ''
			when "CM"
				baseRate = findRateCM(detailRecord)
				plusRate = ''
			when "CP"
				baseRate = findRateCP(detailRecord, 'base') # .dup necessary for weight re-formating in a base + plus scenario.
				plusRate = findRateCP(detailRecord, 'plus')
			when "EX"
				baseRate = findRateEX(detailRecord, 'base')
				plusRate = findRateEX(detailRecord, 'plus')
			when "FC"
				baseRate = findRateFC(detailRecord, 'base')
				plusRate = findRateFC(detailRecord, 'plus')
			when "IE"
				baseRate = findRateIE(detailRecord, 'base')
				plusRate = findRateIE(detailRecord, 'plus')
			when "LC"
				baseRate = findRateLC(detailRecord, 'base')
				plusRate = findRateLC(detailRecord, 'plus') 
			when "LW"
				baseRate = findRateLW(detailRecord)
				plusRate = ''
			when "PG"
				baseRate = findRatePG(detailRecord, 'base')
				plusRate = findRatePG(detailRecord, 'plus')
			when "PM"
				baseRate = findRatePM(detailRecord, 'base')
				plusRate = findRatePM(detailRecord, 'plus')
			when "PS"
				baseRate = findRatePS(detailRecord)
				plusRate = ''
			when "S2"
				baseRate = findRateSM(detailRecord)
				plusRate = ''
			when "SA"
				baseRate = findRateSM(detailRecord)
				plusRate = ''
			end
			
			baseRate = validateRate(baseRate)
			plusRate = validateRate(plusRate)
			
			file.write("\n")
			#file.write("#{detailRecord['Tracking Number']},#{baseRate},#{plusRate}")
			file.write("'#{detailRecord['Tracking Number']}',#{detailRecord['Processing Category']},#{detailRecord['Rate Indicator']},#{detailRecord['Destination Rate Indicator']},#{detailRecord['Length']},#{detailRecord['Height']},#{detailRecord['Width']},#{detailRecord['Weight']},#{detailRecord['Domestic Zone']},#{baseRate},#{plusRate}")
			file.close()
		end
	end
	#*********************************************************************************************************************************
	def findRateBB(detailRecord)
		detailRecord['Domestic Zone'] = '01' if detailRecord['Domestic Zone'] == '02'
		detailRecord['Weight'] = formatPounds(detailRecord['Weight'])
		
		if detailRecord['Rate Indicator'] == "NP"
			rateTable = loadTable("BBNP.csv")
			rateTable.each do |rate|
				return rate[detailRecord['Domestic Zone']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
			end
		elsif detailRecord['Rate Indicator'] == "PR"
			if detailRecord['Destination Rate Indicator'] == 'B'
				rateTable = loadTable("BBPRB.csv")
				rateTable.each do |rate|
					if detailRecord['Domestic Zone'] == rate['Zone']
						rateTotal = rate['Per Piece'].to_f. + (detailRecord['Weight'].to_f * rate['Per Pound'].to_f)
						return rateTotal.round(2).to_s
					end
				end
			elsif detailRecord['Destination Rate Indicator'] == 'N'
				rateTable = loadTable("BBPRN.csv")
				rateTable.each do |rate|
					if detailRecord['Domestic Zone'] == rate['Zone']
						rateTotal = rate['Per Piece'].to_f + (detailRecord['Weight'].to_f * rate['Per Pound'].to_f)
						return rateTotal.round(2).to_s
					end
				end
			elsif detailRecord['Destination Rate Indicator'] == 'S' or detailRecord['Destination Rate Indicator'] == 'D'
				rateTable = loadTable("BBPRSorD.csv")
				rateTable.each do |rate|
					if detailRecord['Destination Rate Indicator'] == rate['Destination Rate Indicator']
						rateTotal = rate['Per Piece'].to_f + (detailRecord['Weight'].to_f * rate['Per Pound'].to_f)
						return rateTotal.round(2).to_s
					end
				end	
			end
		end
	end
	#*********************************************************************************************************************************
	def findRateBL(detailRecord)
		detailRecord['Weight'] = formatPounds(detailRecord['Weight'])
		rateTable = loadTable("BL.csv")
		rateTable.each do |rate|
			return rate[detailRecord['Rate Indicator']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
		end
	end
	#*********************************************************************************************************************************
	def findRateBS(detailRecord)
		detailRecord['Weight'] = formatPounds(detailRecord['Weight'])
		rateTable = loadTable("BS.csv")
		rateTable.each do |rate|
			return rate[detailRecord['Rate Indicator']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
		end
	end
	#*********************************************************************************************************************************
	def findRateCM(detailRecord)
		rateTable = loadTable("CM.csv")
		rateTable.each do |rate|
			return rate['Rate'] if detailRecord['Rate Indicator'] == rate['Rate Indicator']
		end
	end
	#*********************************************************************************************************************************
	def findRateCP(detailRecord, rateTier)
		detailRecord['Customer Reference Number 1'] = formatGroup(detailRecord['Customer Reference Number 1'])
		detailRecord['Weight'] = formatPounds(detailRecord['Weight']) if rateTier == 'base'
		
		flatRateTable = loadTable("baseCPFlat.csv") if rateTier == 'base'
		flatRateTable = loadTable("plusCPFlat.csv") if rateTier == 'plus'
		flatRateTable.each do |flatRate|
			if detailRecord['Rate Indicator'] == flatRate['Rate Indicator']
				return flatRate['CA'] if detailRecord['Destination Country Code'] == 'CA'
				return flatRate['Other'] if detailRecord['Destination Country Code'] != 'CA'
			end
		end
		rateTable = loadTable("baseCP.csv") if rateTier == 'base'
		rateTable = loadTable("plusCP.csv") if rateTier == 'plus'
		rateTable.each do |rate|
			return rate[detailRecord['Customer Reference Number 1']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
		end
	end
	#*********************************************************************************************************************************
	def findRateEX(detailRecord, rateTier)
		detailRecord['Domestic Zone'] = '00' if ['01','02'].include?(detailRecord['Domestic Zone'])
		detailRecord['Weight'] = formatPounds(detailRecord['Weight']) if rateTier == 'base'
		
		rateTable = loadTable("baseEX.csv") if rateTier == 'base'
		rateTable = loadTable("plusEX.csv") if rateTier == 'plus'
		rateTable.each do |rate|
			return rate[detailRecord['Domestic Zone']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
		end
	end
	#*********************************************************************************************************************************
	def findRateFC(detailRecord, rateTier)
		detailRecord['Weight'] = formatOunces(detailRecord['Weight']) if rateTier == 'base'
		detailRecord['Rate Indicator'] = 'MA' if detailRecord['Rate Indicator'] == 'SP'
		
		retailRateTable = loadTable("retailFC.csv") #Catch Rate Indicator 'S2' which uses FC Retail Rate Tables
		if retailRateTable[0].keys.include?(detailRecord['Rate Indicator'])
			retailRateTable.each do |rate|
				return rate[detailRecord['Rate Indicator']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
			end
		end
		
		baseRateTable = loadTable("baseFC.csv")
		baseRateTable.each do |rate|
			if detailRecord['Weight'].to_f <= rate['Weight'].to_f
				return rate[detailRecord['Rate Indicator']] if rate.keys.include?(detailRecord['Rate Indicator'])
			end
		end
		plusRateTable = loadTable("plusFC.csv")
		plusRateTable.each do |rate|
			if detailRecord['Weight'].to_f <= rate['Weight'].to_f
				return rate[detailRecord['Rate Indicator']] if rate.keys.include?(detailRecord['Rate Indicator']) and rateTier == 'plus'
				return '' if rate.keys.include?(detailRecord['Rate Indicator']) and rateTier == 'base' #Comm Plus FC Rate Indicators filter if price tier is set to 'base'.
			end
		end
	end
	#*********************************************************************************************************************************
	def findRateIE(detailRecord, rateTier)
		detailRecord['Customer Reference Number 1'] = formatGroup(detailRecord['Customer Reference Number 1'])
		detailRecord['Weight'] = formatPounds(detailRecord['Weight']) if rateTier == 'base'
		
		flatRateTable = loadTable("baseIEFlat.csv") if rateTier == 'base'
		flatRateTable = loadTable("plusIEFlat.csv") if rateTier == 'plus'
		flatRateTable.each do |flatRate|
			if detailRecord['Rate Indicator'] == flatRate['Rate Indicator']
				return flatRate['CA'] if detailRecord['Destination Country Code'] == 'CA'
				return flatRate['Other'] if detailRecord['Destination Country Code'] != 'CA'
			end
		end
		rateTable = loadTable("baseIE.csv") if rateTier == 'base'
		rateTable = loadTable("plusIE.csv") if rateTier == 'plus'
		rateTable.each do |rate|
			return rate[detailRecord['Customer Reference Number 1']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
		end
	end
	#*********************************************************************************************************************************
	def findRateLC(detailRecord, rateTier)
		detailRecord['Customer Reference Number 1'] = formatGroup(detailRecord['Customer Reference Number 1'])
		detailRecord['Customer Reference Number 1'] = '3-5' if ['3','4','5'].include?(detailRecord['Customer Reference Number 1'])
		detailRecord['Customer Reference Number 1'] = '6-9' if ['6','7','8','9'].include?(detailRecord['Customer Reference Number 1'])
		detailRecord['Weight'] = formatOunces(detailRecord['Weight']) if rateTier == 'base'
		
		rateTable = loadTable("baseLC.csv") if rateTier == 'base'
		rateTable = loadTable("plusLC.csv") if rateTier == 'plus'
		rateTable.each do |rate|
			return rate[detailRecord['Customer Reference Number 1']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
		end
	end
	#*********************************************************************************************************************************
	def findRateLW(detailRecord)
		detailRecord['Weight'] = formatOunces(detailRecord['Weight'])
		
		case detailRecord['Rate Indicator']
		when 'BB'
			rateTable = loadTable("regularBBLW.csv") if detailRecord['Processing Category'] == '3'
			rateTable = loadTable("irregularBBLW.csv") if detailRecord['Processing Category'] == '4'
			rateTable.each do |rate|
				return rate[detailRecord['Destination Rate Indicator']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
			end
		when 'DC'
			rateTable = loadTable("regularDCLW.csv") if detailRecord['Processing Category'] == '3'
			rateTable = loadTable("irregularDCLW.csv") if detailRecord['Processing Category'] == '4'
			rateTable.each do |rate|
				return rate[detailRecord['Destination Rate Indicator']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
			end
		when 'DE'
			rateTable = loadTable("irregularDELW.csv") #DE only has PC 4 (irregular)
			rateTable.each do |rate|
				return rate[detailRecord['Destination Rate Indicator']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
			end
		when 'DF'
			rateTable = loadTable("regularDFLW.csv") if detailRecord['Processing Category'] == '3'
			rateTable = loadTable("irregularDFLW.csv") if detailRecord['Processing Category'] == '4'
			rateTable.each do |rate|
				return rate[detailRecord['Destination Rate Indicator']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
			end
		end
	end
	#*********************************************************************************************************************************
	def findRatePG(detailRecord, rateTier)
		detailRecord['Customer Reference Number 1'] = formatGroup(detailRecord['Customer Reference Number 1'])
		detailRecord['Weight'] = formatPounds(detailRecord['Weight']) if rateTier == 'base'
		
		rateTable = loadTable("basePG.csv") if rateTier == 'base'
		rateTable = loadTable("plusPG.csv") if rateTier == 'plus'
		rateTable.each do |rate|
			return rate[detailRecord['Customer Reference Number 1']] if detailRecord['Weight'].to_f <= rate['Weight'].to_f
		end
	end
	#*********************************************************************************************************************************
	def findRatePM(detailRecord, rateTier)
		detailRecord['Domestic Zone'] = '00' if ['01','02'].include?(detailRecord['Domestic Zone'])
		detailRecord['Weight'] = formatPounds(detailRecord['Weight']) if rateTier == 'base'
		detailRecord['Weight'] = calcDimWeight(detailRecord['Rate Indicator'], detailRecord['Weight'], detailRecord['Length'], detailRecord['Height'], detailRecord['Width']) if rateTier == 'base'
		
		cubicRates = ['CP','P5','P6','P7','P8','P9']
		if cubicRates.include?(detailRecord['Rate Indicator'])
			detailRecord['Length'] = formatCubic(detailRecord['Length']) if rateTier == 'base'
			detailRecord['Height'] = formatCubic(detailRecord['Height']) if rateTier == 'base'
			detailRecord['Width'] = formatCubic(detailRecord['Width']) if rateTier == 'base'
			tier = calcTier(detailRecord['Length'], detailRecord['Height'], detailRecord['Width'])
			detailRecord['Rate Indicator'] = 'SP' if tier > 0.50 #Catch pieces that are greater than 0.50 cubic feet, which are recalculated at Single Piece pricing.
			if detailRecord['Rate Indicator'] != 'SP'
				cubicRateTable = loadTable("cubicPM.csv")
				cubicRateTable.each do |cubicRate|
					if tier <= cubicRate['Tier'].to_f
						return cubicRate[detailRecord['Domestic Zone']] if rateTier == 'plus'
						return '' if rateTier == 'base'
					end
				end
			end
		end
		
		rateTableCM = loadTable("CM.csv") #Catch Critical Mail rate indicators in a PM-type detail record.
		rateTableCM.each do |rate|
			return rate['Rate'] if detailRecord['Rate Indicator'] == rate['Rate Indicator']
		end
		
		boxRateTable = loadTable("PMRegionalBox.csv")
		boxRateTable.each do |boxRate|
			return boxRate[detailRecord['Domestic Zone']] if detailRecord['Rate Indicator'] == boxRate['Rate Indicator']
		end
		
		pmodRateTable = loadTable("pmodDDU.csv") if detailRecord['Destination Rate Indicator'] == 'D'
		pmodRateTable = loadTable("pmodOther.csv") if detailRecord['Destination Rate Indicator'] != 'D'
		pmodRateTable.each do |pmodRate|
			return pmodRate[detailRecord['Domestic Zone']] if detailRecord['Rate Indicator'] == pmodRate['Rate Indicator'] and rateTier == 'plus'
			return '' if ['O5','O6','O7','O8'].include?(detailRecord['Rate Indicator']) #O5 through O8 are CSSC only PMOD Container rates.  There are no published rates for them.
			return '' if detailRecord['Rate Indicator'] == pmodRate['Rate Indicator'] and rateTier == 'base'
		end
		
		flatRateTable = loadTable("basePMFlat.csv") if rateTier == 'base'
		flatRateTable = loadTable("plusPMFlat.csv") if rateTier == 'plus'
		flatRateTable.each do |flatRate|
			return flatRate['Rate'] if detailRecord['Rate Indicator'] == flatRate['Rate Indicator']
		end
		
		rateTable = loadTable("basePM.csv") if rateTier == 'base'
		rateTable = loadTable("plusPM.csv") if rateTier == 'plus'
		rateTable.each do |rate|
			if detailRecord['Rate Indicator'] == 'BN'
				return rate[detailRecord['Domestic Zone']] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
			elsif detailRecord['Weight'].to_f <= rate['Weight'].to_f
				return rate[detailRecord['Domestic Zone']]
			end
		end
	end
	#*********************************************************************************************************************************
	def findRatePS(detailRecord)
		detailRecord['Domestic Zone'] = '00' if ['01','02'].include?(detailRecord['Domestic Zone'])
		detailRecord['Weight'] = formatPounds(detailRecord['Weight'])
		
		if detailRecord['Destination Rate Indicator'] == 'B'
			rateTable = loadTable("PSDestEntry3B.csv") if detailRecord['Processing Category'] == '3'
			rateTable = loadTable("PSDestEntry5DorB.csv") if detailRecord['Processing Category'] == '5'
			rateTable.each do |rate|
				if detailRecord['Rate Indicator'] == 'BN'
					return rate[detailRecord['Domestic Zone']] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
				elsif detailRecord['Rate Indicator'] == 'OS'
					return rate[detailRecord['Domestic Zone']] if rate['Weight'] == 'OS' #Catches 'OS' (Balloon) rate cells.
				elsif detailRecord['Weight'].to_f <= rate['Weight'].to_f
					return rate[detailRecord['Domestic Zone']]
				end
			end
		elsif detailRecord['Processing Category'] == '5' and detailRecord['Destination Rate Indicator'] == 'D'
			rateTable = loadTable("PSDestEntry5DorB.csv")
			rateTable.each do |rate|
				if detailRecord['Rate Indicator'] == 'BN'
					return rate[detailRecord['Domestic Zone']] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
				elsif detailRecord['Rate Indicator'] == 'OS'
					return rate[detailRecord['Domestic Zone']] if rate['Weight'] == 'OS' #Catches 'OS' (Balloon) rate cells.
				elsif detailRecord['Weight'].to_f <= rate['Weight'].to_f
					return rate[detailRecord['Domestic Zone']]
				end
			end
		elsif detailRecord['Processing Category'] == '3' and (detailRecord['Destination Rate Indicator'] == 'D' or detailRecord['Destination Rate Indicator'] == 'S')
			rateTable = loadTable("PSDestEntry3DorS.csv")
			rateTable.each do |rate|
				if detailRecord['Rate Indicator'] == 'BN'
					return rate[detailRecord['Destination Rate Indicator']] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
				elsif detailRecord['Weight'].to_f <= rate['Weight'].to_f
					return rate[detailRecord['Destination Rate Indicator']]
				end
			end
		elsif detailRecord['Processing Category'] == '5' and detailRecord['Destination Rate Indicator'] == 'S'
			rateTable = loadTable("PSDestEntry5S.csv")
			rateTable.each do |rate|
				if detailRecord['Rate Indicator'] == 'BN'
					return rate['5D'] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.  5 BN S uses 5-Digit (5D) rate column.
				elsif detailRecord['Rate Indicator'] == 'OS'
					return rate['5D'] if rate['Weight'] == 'OS' #Catches 'OS' (Balloon) rate cells. 5 OS S uses 5-Digit (5D) rate column.
				elsif detailRecord['Weight'].to_f <= rate['Weight'].to_f
					return rate[detailRecord['Rate Indicator']]
				end
			end
		end
		
		rateTable = loadTable("PSNDCPresort.csv") if ['D3','D9'].include?(detailRecord['Discount Type'])  #Catch NDC Discount Types
		rateTable = loadTable("PSONDCPresort.csv") if ['D2','D8'].include?(detailRecord['Discount Type']) #Catch ONDC Discount Types
		rateTable = loadTable("PSNonPresort.csv") if detailRecord['Discount Type'] == '' #Catch any remaining PS Non-presort
		rateTable.each do |rate|
			if detailRecord['Rate Indicator'] == 'BN'
				return rate[detailRecord['Domestic Zone']] if rate['Weight'] == 'BN' #Catches 'BN' (Balloon) rate cells.
			elsif detailRecord['Rate Indicator'] == 'OS'
				return rate[detailRecord['Domestic Zone']] if rate['Weight'] == 'OS' #Catches 'OS' (Balloon) rate cells.
			elsif detailRecord['Weight'].to_f <= rate['Weight'].to_f
				return rate[detailRecord['Domestic Zone']]
			end
		end
	end
	#*********************************************************************************************************************************
	def findRateSM(detailRecord)
		detailRecord['Weight'] = formatPounds(detailRecord['Weight'])
		nonProfit = isNonProfit(detailRecord['Rate Indicator'])
		
		if nonProfit
			if detailRecord['Weight'].to_f <= 0.20625
				#rateTable = loadTable("SMNPUnder3Presorted.csv") if detailRecord['Processing Category'] == '3' #Presorted Marketing Parcels (SA)
				#rateTable = loadTable("SMNPUnder3Irregular.csv") if detailRecord['Processing Category'] == '4' #Irregular
				rateTable = loadTable("SMNPUnder3Presorted.csv") if detailRecord['Processing Category'] == '3' or detailRecord['Mail Class'] == 'S2' #Machinable SA and all S2
				rateTable = loadTable("SMNPUnder3Irregular.csv") if detailRecord['Processing Category'] == '4' and detailRecord['Mail Class'] == 'SA'#Irregular SA
				rateTable.each do |rate|
					return rate[detailRecord['Rate Indicator']] if detailRecord['Destination Rate Indicator'] == rate['Destination Rate Indicator']
				end
			elsif detailRecord['Weight'].to_f > 0.20625
				perPiece = 0.0
				perOunce = 0.0
				#rateTable = loadTable("SMNPOver3Presorted.csv") if detailRecord['Processing Category'] == '3' and detailRecord['Mail Class'] == 'SA' #Presorted Marketing Parcels
				#rateTable = loadTable("SMNPOver3Mach.csv") if detailRecord['Processing Category'] == '3' and detailRecord['Mail Class'] == 'S2' #Machinable Standard Mail Parcels
				#rateTable = loadTable("SMNPOver3Irregular.csv") if detailRecord['Processing Category'] == '4' #Irregular
				rateTable = loadTable("SMNPOver3Presorted.csv") if detailRecord['Processing Category'] == '3' or detailRecord['Mail Class'] == 'S2' #Machinable SA and all S2
				rateTable = loadTable("SMNPOver3Irregular.csv") if detailRecord['Processing Category'] == '4' and detailRecord['Mail Class'] == 'SA'#Irregular SA
				rateTable.each do |rate|
					perPiece = rate[detailRecord['Rate Indicator']].to_f if rate['Destination Rate Indicator'] == 'Per Piece'
					perOunce = rate[detailRecord['Rate Indicator']].to_f if detailRecord['Destination Rate Indicator'] == rate['Destination Rate Indicator']
				end
				return (perPiece + detailRecord['Weight'].to_f * perOunce).round(4).to_s
			end
		else
			if detailRecord['Weight'].to_f <= 0.20625
				rateTable = loadTable("S2Under3.csv")
				rateTable.each do |rate|
					return rate[detailRecord['Rate Indicator']] if detailRecord['Destination Rate Indicator'] == rate['Destination Rate Indicator']
				end
			elsif detailRecord['Weight'].to_f > 0.20625
				perPiece = 0.0
				perOunce = 0.0
				rateTable = loadTable("S2Over3.csv")
				rateTable.each do |rate|
					perPiece = rate[detailRecord['Rate Indicator']].to_f if rate['Destination Rate Indicator'] == 'Per Piece'
					perOunce = rate[detailRecord['Rate Indicator']].to_f if detailRecord['Destination Rate Indicator'] == rate['Destination Rate Indicator']
				end
				return (perPiece + detailRecord['Weight'].to_f * perOunce).round(4).to_s
			end
		end
		
	end
	#*********************************************************************************************************************************
	def isNonProfit(rateInd)
		return true if rateInd[0] == 'N'  #All Standard Mail Non-Profit Rate Ingredients start with 'N' (N5, NT, NM, etc)
		return false if rateInd[0] != 'N' #Standard Mail (for profit) Rate Ingredients do not start with 'N' (5D, 3D, BM, MB, etc)
	end
	#*********************************************************************************************************************************
	#Re-format weight from manifest formatting
	def formatPounds(value)
		wholeNum = value[1, 4] #Pulls the 2nd (A), 3rd (B), 4th (C) and 5th (D) digit from the format 0ABCDdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = value[5, 4]  #Pulls the decimal portion
		return "#{wholeNum}.#{decimal}"
	end
	#*********************************************************************************************************************************
	#Re-format weight from manifest formatting
	def formatOunces(value)
		wholeNum = value[1, 4] #Pulls the 2nd (A), 3rd (B), 4th (C) and 5th (D) digit from the format 0ABCDdddd where 'd' is the decimal portion of the eVS weight convention
		decimal = value[5, 4]  #Pulls the decimal portion
		return ("#{wholeNum}.#{decimal}".to_f * 16.0).round(4).to_s
	end
	#*********************************************************************************************************************************
	#Re-format Price Group value -- trim out "Price Group" from "Price Group #" format as found in the Customer Reference Number 1 Field
	def formatGroup(value)
		return value.delete("Price Group").chomp
	end
	#*********************************************************************************************************************************
	#Priority Mail Cubic Price Tier calculations require each dimension be rounded down to the nearest 1/4th inch.  Format the values and round appropriately.
	def formatCubic(value)
		wholeNum = value[1,2].to_f #Pulls the whole number portion from 00 to 99 of the eVS dimension/size convention
		decimal = "0.#{value[3, 2]}".to_f #Pulls the decimal portion

		quarterVals = [0.00, 0.25, 0.50, 0.75]
		quarterVals.each_with_index do |val, index|
			return (wholeNum + decimal).to_s if decimal == val
			return (wholeNum + quarterVals[index - 1]).to_s if decimal < val
			return (wholeNum + quarterVals.last).to_s if decimal > quarterVals.last
		end
	end
	#*********************************************************************************************************************************
	#Determine the Priority Mail Cubic Price Tier
	def calcTier(length, height, width)
		return (length.to_f * height.to_f * width.to_f)/1728.0
	end
	#*********************************************************************************************************************************
	def calcDimWeight(rateInd, weight, length, height, width) #Calculate dimensional weight for Dimensional Rect. and Non-Rect.
		length = "#{length[1,2]}.#{length[3,2]}".to_f.round #Re-formats and rounds to nearest whole inch.
		height = "#{height[1,2]}.#{height[3,2]}".to_f.round #Re-formats and rounds to nearest whole inch.
		width = "#{width[1,2]}.#{width[3,2]}".to_f.round #Re-formats and rounds to nearest whole inch.

		if rateInd == 'DR'
			dimWeight = ((length * height * width)/194.0)
			splitNum = dimWeight.to_s.split('.')
			dimWeight = splitNum[0].to_f + 1.0 if splitNum[1].to_f > 0.00
			return dimWeight.to_s if dimWeight > weight.to_f
			return weight if dimWeight < weight.to_f
		elsif rateInd == 'DN'
			dimWeight = (((length * height * width)*0.785)/194.0)
			splitNum = dimWeight.to_s.split('.')
			dimWeight = splitNum[0].to_f + 1.0 if splitNum[1].to_f > 0.00
			return dimWeight.to_s if dimWeight > weight.to_f
			return weight if dimWeight < weight.to_f
		else
			return weight
		end
	end
	#*********************************************************************************************************************************
	def validateRate(rate) #Ensure a reasonable rate amount is being calculated/returned.  Otherwise set it to '' to represent an invalid rate.
		if rate.size > 10
			return ''
		else
			return rate
		end
	end
	#*********************************************************************************************************************************
	def loadTable(tableName)
		rateTable = []
		rateCells = {}
		file = File.open("#{@rateLocation}#{tableName}",'r')
		tableColumns = file.readline.chomp.split(',')
		file.each_line do |line|
			rate = line.chomp.split(',')
			tableColumns.each_with_index do |field, index|
				rateCells.merge!(field.to_s => rate[index].to_s)
			end
			rateTable << rateCells.dup if rateCells.empty? == false
			rateCells.clear
		end
		file.close()
		return rateTable
	end
	#*********************************************************************************************************************************
	def grabEFN(efn)
		file = File.rename("#{$targetPath}/ref/TEMP_rateCheck#{@mailClass}.csv", "#{$targetPath}/ref/#{efn}_rateCheck#{@mailClass}.csv")
	end
	#*********************************************************************************************************************************
end