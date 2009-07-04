# -*- coding: utf-8 -*-

require 'digest/md5'
require 'ftools'

class CoursesController < ApplicationController
  # GET /courses
  # GET /courses.xml
  def index
    @courses = Course.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @courses }
    end
  end

  # GET /courses/1
  # GET /courses/1.xml
  def show
    @course = Course.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @course }
    end
  end

  # GET /courses/new
  # GET /courses/new.xml
  def new
    @course = Course.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @course }
    end
  end

  # GET /courses/1/edit
  def edit
    @course = Course.find(params[:id])
  end

  # POST /courses
  # POST /courses.xml
  def create
    @course = Course.new(params[:course])

    respond_to do |format|
      if @course.save
        flash[:notice] = 'Course was successfully created.'
        format.html { redirect_to(@course) }
        format.xml  { render :xml => @course, :status => :created, :location => @course }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /courses/1
  # PUT /courses/1.xml
  def update
    @course = Course.find(params[:id])

    respond_to do |format|
      if @course.update_attributes(params[:course])
        flash[:notice] = 'Course was successfully updated.'
        format.html { redirect_to(@course) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1
  # DELETE /courses/1.xml
  def destroy
    @course = Course.find(params[:id])
    @course.destroy

    respond_to do |format|
      format.html { redirect_to(courses_url) }
      format.xml  { head :ok }
    end
  end
  
  # DELETE /courses/drop_prof?course=1&prof=1
  def drop_prof
    @course = Course.find(params[:id])
    @prof = Prof.find(params[:prof_id])
    @course.profs.delete(@prof)
    
    respond_to do |format|
      format.html { redirect_to(@course) }
      format.xml { head :ok }
    end
  end
  
  def add_prof
    @course = Course.find(params[:id])
    @prof = Prof.find(params[:courses][:profs])
    @course.profs << @prof
    
    respond_to do |format|
      format.html { redirect_to(@course) }
      format.xml { head :ok }
    end
  end
  def get_direct_die_roms_stinken_pdf(c)
    @course = c
    workdir = '/var/www-seee/web/public/forms/'
    hexdigest = Digest::SHA256.hexdigest(@course.id.to_s + @course.title)    
    filename = @course.students.to_s + '_' + hexdigest
    if not FileTest.exists?(workdir + filename + '.pdf')
      b = Evalbogen.new
      b.workdir = workdir
      b.dozent = ''
      b.tutoren = @course.tutors.map { |t| t.abbr_name}.reverse
      b.semester = @course.semester.title
      b.veranstaltung = @course.title
      @course.form ||= 0
      b.bogen_basefile = @course.form.to_s
      
      b.output_to_file_and_compile(filename)
    end    
    
    File.copy(workdir + filename + '.pdf', './' + @course.title + ' - ' + @course.id.to_s + ' - ' + @course.students.to_s + ' pcs.pdf')
  end
  def get_direct_pdf(c,p)
    @course = c
    @prof = p
    workdir = '/var/www-seee/web/public/forms/'
    hexdigest = Digest::SHA256.hexdigest(@prof.fullname + @course.title)    
    filename = @course.students.to_s + '_' + hexdigest
    if not FileTest.exists?(workdir + filename + '.pdf')
      b = Evalbogen.new
      b.workdir = workdir
      b.tutoren = @course.tutors.map { |t| t.abbr_name}.reverse
      b.dozent = @prof.fullname
      b.semester = @course.semester.title
      b.veranstaltung = @course.title
      @course.form ||= 0
      b.bogen_basefile = @course.form.to_s
      b.barcodeid = "%07d" % @course.course_profs.find(:first, :conditions => { :prof_id => @prof.id }).id
      b.barcodefile = hexdigest + '_' + b.barcodeid + '_bcf' 
      b.generate_barcode
      
      b.output_to_file_and_compile(filename)
    end    
    
    File.copy(workdir + filename + '.pdf', './' + @course.title + ' - ' + @prof.fullname + ' - ' + @course.students.to_s + ' pcs.pdf')
  end  


  # GET /courses/get_pdf?course=1&prof_id=1
  def get_pdf
    @course = Course.find(params[:id])
    @prof = Prof.find(params[:prof_id])
    workdir = '/var/www-seee/web/public/forms/'
    hexdigest = Digest::SHA256.hexdigest(@prof.fullname + @course.title)    
    filename = @course.students.to_s + '_' + hexdigest
    if not FileTest.exists?(workdir + filename + '.pdf')
      b = Evalbogen.new
      b.workdir = workdir
      b.tutoren = @course.tutors.map { |t| t.abbr_name}.reverse
      b.dozent = @prof.fullname
      b.semester = @course.semester.title
      b.veranstaltung = @course.title
      @course.form ||= 0
      b.bogen_basefile = @course.form.to_s
      b.barcodeid = "%07d" % @course.course_profs.find(:first, :conditions => { :prof_id => @prof.id }).id
      b.barcodefile = hexdigest + '_' + b.barcodeid + '_bcf' 
      b.generate_barcode
      
      b.output_to_file_and_compile(filename)
    end    
    
    respond_to do |f|
      f.html { send_file workdir + filename + '.pdf', :filename => @course.title + ' - ' + @prof.fullname + ' - ' + @course.students.to_s + ' pcs.pdf' }
      f.xml { head :ok }
    end
  end
  def get_fresh_pdf
    @course = Course.find(params[:id])
    @prof = Prof.find(params[:prof_id])
    workdir = '/var/www-seee/web/public/forms/'
    hexdigest = Digest::SHA256.hexdigest(@prof.fullname + @course.title)    
    filename = @course.students.to_s + '_' + hexdigest
    if FileTest.exists?(workdir + filename + '.pdf')
      File.delete(workdir + filename + '.pdf')
      `touch /var/www-seee/boohoo`
    end
    get_pdf
  end
end

class Evalbogen

  # b = Evalbogen.new
  # b.tutoren=["Mustafa Msutermann", "MyPhi", "Specki", "Petra Meier",
  #  "Patricia Bayer", "Klothilde Müller", "Claire Grupe", "Armin
  #   Gibs", "Karsten Bier", "Etienne Mbe Mbock",
  #  "Sigfried-P. Weizenäcker"] 
  # b.dozent = "Prof. Dr. hc. mul. M. Phys"
  # b.veranstaltung = "Mein kleiner grüner Kaktus -- das Lied"
  # b.semester = "SS 2008"
  # b.barcodefile = "test.pdf"
  # b.output

  attr_accessor :veranstaltung, :dozent, :semester, :tutoren, :barcodefile, :barcodeid, :bogen_basefile, :workdir
  def generate_barcode
    `barcode -b "#{@barcodeid}" -g 80x30 -u mm -e EAN -n -o #{@workdir + @barcodefile}.ps && ps2pdf #{@workdir + barcodefile}.ps #{@workdir + @barcodefile}.pdf && rm #{@workdir + @barcodefile}.ps`
  end
  def cleanup
    `rm #{@workdir + @barcodefile}.pdf`
  end
  def output_to_file_and_compile(filename)
    `echo "#{output}" > #{@workdir + filename}.tex`
    `cd #{@workdir} && pdflatex #{filename} && popd`
    ['aux', 'log', 'toc', 'eps', 'tex'].each { |ext| `rm #{@workdir + filename}*.#{ext}` }
    cleanup
  end
  def output
    buffer = ""
    buffer += '\documentclass[a4paper,twoside]{article}
\usepackage[absolute]{textpos}
\usepackage{graphicx}
\usepackage{helvet}
\usepackage{amssymb}
\usepackage[utf8]{inputenc}
\pagestyle{empty}
\renewcommand{\familydefault}{\sfdefault}
\parindent0mm
\begin{document}
\begin{textblock*}{1cm}(0mm,0mm)
\setlength{\unitlength}{1mm}
\begin{picture}(0,0)(0,0)
\thinlines
\put(0,-297){\includegraphics*{' + @bogen_basefile  + '_1.pdf}} % erste seite evalbogen' + "\n"
    if not(@barcodefile.nil?)
      buffer += '\put(158,-20){\includegraphics*{' + @barcodefile + '.pdf}} % barcode' + "\n"
    end
    buffer += '\fontsize{11pt}{21}\selectfont
\put(22,-37.3){\normalsize '+ @veranstaltung + '}
\put(111,-37.3){\normalsize ' + @dozent + '}
\put(177,-37.3){\normalsize '+ @semester +'}' + "\n"
    
    # kaestchen malen und mit tutoren beschriften

    (0..5).each do |i|
      (0..4).each do |j|
        buffer += draw_fucking_box(12.3+37*j,-51-7*i)
        if not (!@tutoren.empty?)
          buffer += '\put(' + (12.3+37*j+5).to_s + ',' + (-51-7*i).to_s + '){\footnotesize \raisebox{0.6mm}{' + @tutoren.pop + '}}' + "\n"
        end
      end
    end

    buffer += '\end{picture}
\end{textblock*}
\null\newpage

\begin{textblock*}{1cm}(0mm,0mm)
\setlength{\unitlength}{1mm}
\begin{picture}(0,0)(0,0)
\thinlines
\put(0,-297){\includegraphics*{' + @bogen_basefile + '_2.pdf}} % erste seite evalbogen
\end{picture}
\end{textblock*}
\null\newpage
\cleardoublepage

\end{document}'
    buffer
  end

  def draw_fucking_box(x,y)
    '\put(' + x.to_s + ',' + y.to_s + '){\linethickness{0.1mm}\line(1,0){3.6}}
\put(' + (x+3.6).to_s + ',' + y.to_s + '){\linethickness{0.1mm}\line(0,1){3.6}}
\put('+x.to_s+',' + y.to_s + '){\linethickness{0.1mm}\line(0,1){3.6}}
\put('+x.to_s+',' + (y+3.6).to_s + '){\linethickness{0.1mm}\line(1,0){3.6}}' + "\n"
  end
end

