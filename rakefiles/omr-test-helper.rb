namespace :testhelper do
  Scc = Seee::Config.commands

  desc "debugs the sample sheets as if they were scanned so you can see if OMR is working correctly"
  task :debug_samplesheets, :needs => 'pdf:samplesheets' do |t, a|
    puts "NOTE: Old sample sheets will not be overwritten. If you updated them,"
    puts "      remove the sample sheets directory first before running this."
    puts
    puts
    Dir.chdir("tmp/sample_sheets") do
      Dir.glob("*.yaml") do |f|
        f = f.gsub(/\.yaml$/, "")
        next unless File.exist?("#{f}.pdf")

        unless File.exist?("#{f}.tif")
          puts
          puts "Now converting #{f}.pdf to tif"
          system("#{Scc[:convert]} -compress LZW -density 300 -colors 2 \"#{f}.pdf\" \"#{f}.tif\"")
        end

        puts
        puts "Now running OMR on #{f}.tif"
        system("../../pest/omr2.rb -t -d -v -s \"#{f}.yaml\" -p . #{f}.tif")
      end
    end
  end
end
