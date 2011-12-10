namespace :testhelper do
  Scc = Seee::Config.commands

  # print and execute a command
  def cmd(line)
    puts line
    system line
  end

  desc "debugs the sample sheets as if they were scanned so you can see if OMR is working correctly"
  task :debug_samplesheets, :needs => 'pdf:samplesheets' do
    Dir.chdir("tmp/sample_sheets") do
      Dir.glob("*.yaml") do |f|
        f = f.gsub(/\.yaml$/, "")
        next unless File.exist?("#{f}.pdf")
        # note that the filename for the yaml file and tif file need to be different. Otherwise the
        # TeX’s-YAML file will be overwritten by the processed-YAML file which contains the pixel
        # coordinates instead of the original TeX ones. This makes re-processing cumbersome, as the
        # sample sheets would have to be re-rendered. A proper way to fix this would be if OMR would
        # store the pixels into different variables. FIXME
        unless File.exist?("dbg_#{f}.tif")
          puts
          puts "Now converting #{f}.pdf to tif"
          cmd("#{Scc[:convert]} -density 300 -monochrome \"#{f}.pdf\" \"dbg_#{f}.tif\"")
        end

        puts
        puts "Now running OMR on dbg_#{f}.tif"
        cmd("../../pest/omr2.rb -t -d -v -s \"#{f}.yaml\" -p . dbg_#{f}.tif")
      end
    end
  end
end
