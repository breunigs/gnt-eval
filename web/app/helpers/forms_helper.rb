module FormsHelper
  def nav_links
    s = []
    s << link_to("Edit #{@form.name}", edit_form_path(@form)) unless @form.critical?
    s << link_to('Show rendered preview', "#tex-image-preview")
    s << link_to('Show TeX-Code used for preview', "#tex-code-preview")
    s << link_to('Show Ruby-fied form code', "#ruby-yaml-code")
    s << link_to('List all available forms', forms_path)
    s.join(" | ")
  end


  def render_preview
    require 'rubygems'
    require 'open4'
    require 'base64'

    code = @form.abstract_form.to_tex
    return false, ["(no data?)"], "", "" if code.nil? || code.strip.empty?

    name = Digest::SHA256.hexdigest(code)
    tmppath = File.join(temp_dir, "form_preview")
    File.makedirs(tmppath)
    path = File.join(tmppath, "form_#{@form.id}__#{name}")

    exitcodes = []
    logger = ""

    generate_barcode("0"*8, File.join(tmppath, "barcode#{"0"*8}.pdf"))
    File.open(path + ".tex", 'w') { |f| f << code }

    header("Running PDF LaTex", logger)
    logger << `cd #{tmppath} && #{Seee::Config.commands[:pdflatex_real]} "#{path}.tex" 2>&1`

    exitcodes << $?.to_i
    exitcodes << (File.exists?("#{path}.pdf") ? 0 : 1)

    if exitcodes.total == 0
      header("Converting PDF to PNG", logger)

      # this first converts the PDF to a series of images and passes
      # them to stdout. This is then piped into another convert instance
      # which adds borders to each of them. In the last step the images
      # are combined into one large PNG that is saved to disk (getting
      # it directly via stdout is too slow)
      c = Seee::Config.application_paths[:convert]
      cmd = "#{c} -density 100 \"#{path}.pdf\" MIFF:- | \
	     #{c} MIFF:- -frame 2x2+2 -bordercolor white -border 0x10 MIFF:- | \
	     #{c} MIFF:-  -append \"#{path}.png\""

      # Hand above command to the shell
      exitcodes << Open4::popen4("sh") do |pid, stdin, stdout, stderr|
        stdin.puts cmd
        stdin.close
	logger << stderr.read.strip
      end.exitstatus
    end

    # convert to base64
    exitcodes << (File.exists?("#{path}.png") ? 0 : 1)
    if exitcodes.total == 0
      data = File.open("#{path}.png", 'rb') { |f| f.read }
      base64 = Base64.encode64(data)
    end

    # cleanup temp files
    files = '"' + Dir.glob("#{path}*").join('" "') + '"'
    `rm -rf #{files}`

    return exitcodes.total > 0, exitcodes, logger.gsub("\n", "<br/>"), base64
  end

  private
  def header(text, logger)
    logger << "\n"*4 << "="*50 << text << "="*50 << "\n"
  end
end
