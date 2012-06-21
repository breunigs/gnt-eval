# encoding: utf-8

class TutorsController < ApplicationController
  before_filter :load_course, :except => :index

  def load_course
    @course = Course.find(params[:course_id])
  end

  # GET /tutors
  # GET /tutors.xml
  def index
    # (inner) join prevents us from loading tutors whose course does
    # not exist anymore
    @tutors = Tutor.all(:joins => :course, :include => [:semester],
                :order => ["semester_id DESC", :title, :abbr_name])

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @tutors }
    end
  end

  # GET /tutors/1
  # GET /tutors/1.xml
  def show
    @tutor = Tutor.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tutor }
    end
  end

  # GET /tutors/1/edit
  def edit
    @tutor = Tutor.find(params[:id])
    @course = Course.find(@tutor.course_id)
  end

  # GET /tutors/1/preview
  def preview
    @tutor = Tutor.find(params[:id])

    respond_to do |format|
      format.html # preview.html.erb
    end
  end

  # POST /tutors
  # POST /tutors.xml
  def create
    existingTutors = @course.tutors.map { |x| x.abbr_name }
    par = params[:tutor]['abbr_name'].split(',').map{ |x| x.strip }

    errors = []
    par.uniq.sort.each do |p|
      next if existingTutors.include?(p)
      t = @course.tutors.build({'abbr_name'=>p})
      unless t.save
        errors << t.errors
      end
    end

    kill_caches

    respond_to do |format|
      if errors.empty?
        flash[:notice] = 'Tutor was successfully created.'
        format.html { redirect_to(@course) }
     else
        format.html { render :action => "new" }
      end
    end
  end

  # PUT /tutors/1
  # PUT /tutors/1.xml
  def update
    @tutor = Tutor.find(params[:id])
    kill_caches @tutor
    expire_fragment("tutors_#{params[:id]}") if @tutor.comment != params[:tutor][:comment]

    respond_to do |format|
      if @tutor.update_attributes(params[:tutor])
        flash[:notice] = 'Tutor was successfully updated.'
        format.html { redirect_to([@tutor.course, @tutor]) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tutor.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tutors/1
  # DELETE /tutors/1.xml
  def destroy
    @tutor = Tutor.find(params[:id])

    kill_caches @tutor
    # expire preview cache as well
    expire_fragment("tutors_#{params[:id]}")
    @tutor.destroy unless @tutor.critical?

    respond_to do |format|
      flash[:error] = 'Tutor was critical and has therefore not been destroyed.' if @tutor.critical?
      format.html { redirect_to(@course) }
      format.xml  { head :ok }
    end
  end

  #caches_page :index, :show, :edit, :preview

  private
  def kill_caches(tutor = nil)
    #~ logger.info "="*50
    #~ logger.info "Expiring tutor caches" + (tutor ? " for #{tutor.abbr_name}" : "")
    #~ expire_page :action => "index"
    #~ expire_page :action => "show", :id => tutor
    #~ expire_page :action => "preview", :id => tutor
    #~ expire_page :action => "edit", :id => tutor
  end
end
