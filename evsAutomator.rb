#The EVS/SBP Automator is the master ruby file which contains and executes the following EVS Automation Components:
#1) EVS File Generator
#2) EVS Rate Check
#3) EVS Rate Validator
#4) EVS Command Generator
#5) SBP File Generator

$:.unshift File.dirname($0) #Necessary for OCRA (ruby .exe packager) to load additional files from the same directory as the EVS/SBP Automator

@operations = { '1' => 'Generate EVS Files', '2' => 'Generate SBP Files', '3' => 'Validate EVS Rates', '4' => 'Generate Shell Command' }
@input = ''
@stillWorking = true

def prompt()
	puts "Enter the corresponding number for the operation you want to execute:"
	@operations.each do |key, value|
		puts "#{key}) #{value}"
	end
	print "> "
	@input = gets.chomp
	while (1..@operations.size).include?(@input.to_i) == false
		puts "#{@input} is not a valid selection!  Re-enter a valid selection:"
		print "> "
		@input = gets.chomp
	end
end

puts "Welcome to the EVS/SBP Automator!"
prompt()
while @stillWorking
	case @input
	when '1'
		puts "Selected 1 - #{@operations['1']}!"
		load "manGen.rb"
	when '2'
		puts "Selected 2 - #{@operations['2']}!"
		load "sbpGenerator.rb"
	when '3'
		puts "Selected 3 - #{@operations['3']}!"
		load "varianceReportGrabber.rb"
		load "validateRates.rb"
	when '4'
		puts "Selected 4 - #{@operations['4']}!"
		load "commandGenerator.rb"
	end

	puts "Would you like to perform another operation? (y/n)"
	if gets.chomp.downcase == 'y'
		prompt()
	else
		puts "Exiting the EVS/SBP Automator!"
		@stillWorking = false
	end
end