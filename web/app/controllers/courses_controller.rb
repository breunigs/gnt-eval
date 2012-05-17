# encoding: utf-8

class CoursesController < ApplicationController
  # GET /courses
  # GET /courses.xml
  def index
    @curr_sem ||= view_context.get_selected_semesters
    if @curr_sem.empty?
      flash[:error] = "Cannot list courses for current semester, as there isn’t any current semester. Please create a new one first."
      redirect_to :controller => "semesters", :action => "index"
      return
    end
    # don’t allow URLs that have the search parameter without value
    if params[:search] && params[:search].empty?
      redirect_to :controller => "courses", :action => "index"
      return
    end

    cond = "semester_id IN (?)"
    vals = view_context.get_selected_semesters

    # filter by search term. If none given, search will return all
    # courses that match the additional filter criteria.
    @courses = Course.search(params[:search], [:profs, :faculty], [cond], [vals])

    # if a search was performed and there is exactly one result go to it
    # directly instead of listing it
    if params[:search] && @courses.size == 1
      redirect_to(@courses.first)
      return
    end

    # otherwise, render list of courses
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @courses }
    end
  end

  def search
    @courses = Course.search params[:search]
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
    @curr_sem ||= view_context.get_selected_semesters
    if @curr_sem.empty?
      flash[:error] = "Cannot create a new course for current semester, as there isn’t any current semester. Please create a new one first."
      redirect_to :controller => "semesters", :action => "index"
    else
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @course }
      end
    end
  end

  # GET /courses/1/edit
  def edit
    @course = Course.find(params[:id])
  end

  # GET /courses/1/preview
  def preview
    @course = Course.find(params[:id])

    respond_to do |format|
      format.html # preview.html.erb
    end
  end

  # POST /courses
  # POST /courses.xml
  def create
    @course = Course.new(params[:course])
    kill_caches

    respond_to do |format|
      if form_lang_combo_valid? && @course.save
        flash[:notice] = 'Course was successfully created.'
        format.html { redirect_to(@course) }
        format.xml  { render :xml => @course, :status => :created, :location => @course }
      else
        flash[:error] = "Selected form and language combination isn’t valid." unless form_lang_combo_valid?
        format.html { render :action => "new" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /courses/1
  # PUT /courses/1.xml
  def update
    @course = Course.find(params[:id])
    kill_caches @course
    expire_fragment("courses_#{params[:id]}") if @course.summary != params[:course][:summary]

    respond_to do |format|
      checks = form_lang_combo_valid? && !critical_changes?(@course)
      if checks && @course.update_attributes(params[:course])
        flash[:notice] = 'Course was successfully updated.'
        format.html { redirect_to(@course) }
        format.xml  { head :ok }
      else
        if not @course.form.abstract_form_valid?
          flash[:error] = "The selected form is not valid. Please fix it first."
        elsif !form_lang_combo_valid?
          flash[:error] = "The selected form/language combination isn’t valid. #{flash[:error]}"
        elsif critical_changes?(@course)
          flash[:error] = "Some of the changes are critical. Those are currently not allowed."
        else
          flash[:error] = "Could not update the course."
        end

        format.html { render :action => "edit" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1
  # DELETE /courses/1.xml
  def destroy
    @course = Course.find(params[:id])
    kill_caches @course
    # expire preview cache as well
    expire_fragment("courses_#{params[:id]}")

    unless @course.critical?
      begin
        @course.course_profs.each { |cp| cp.destroy }
        @course.tutors.each { |t| t.destroy }
      end
      @course.destroy
    end

    respond_to do |format|
      flash[:error] = 'Course was critical and has therefore not been destroyed.' if @course.critical?
      format.html { redirect_to(courses_url) }
      format.xml  { head :ok }
    end
  end

  # DELETE /courses/drop_prof?course=1&prof=1
  def drop_prof
    @course = Course.find(params[:id])
    unless @course.critical?
      @prof = Prof.find(params[:prof_id])
      @course.profs.delete(@prof)
    end

    # kill caches and update the deleted prof’s page as well (not
    # catched by kill_caches)
    kill_caches @course
    expire_page :controller => "profs", :action => "show", :id => @prof

    respond_to do |format|
      flash[:error] = "Course was critical and therefore prof #{@prof.fullname} has been kept." if @course.critical?
      format.html { redirect_to(@course) }
      format.xml { head :ok }
    end
  end

  def add_prof
    begin
      @course = Course.find(params[:id])
      @prof = Prof.find(params[:courses][:profs])
      @course.profs << @prof

      # kill caches after the prof is being added, so that the new prof
      # will get an updated page
      kill_caches @course

      respond_to do |format|
        format.html { redirect_to(@course) }
        format.xml { head :ok }
      end
    rescue
      flash[:error] = "Couldn’t add prof. Are you sure the course and selected prof exist?"
      respond_to do |format|
        format.html { redirect_to(@course) }
        format.xml  { render :xml => (@course.nil? ? "" : @course.errors),
          :status => :unprocessable_entity }
      end
    end
  end

  private
  # looks if critical changes to a course were made and reports them iff
  # the course is critical.
  def critical_changes? course
    # if the semester is critical, these fields will not be submitted.
    # supply them from the database instead.
    params[:course][:form_id] ||= course.form.id
    params[:course][:language] ||= course.language
    lang_changed = course.language.to_s != params[:course][:language].to_s
    form_changed = course.form.id.to_s != params[:course][:form_id].to_s
    if course.critical? && (lang_changed || form_changed)
      flash[:error] = "Can’t change the language because the semester is critical." if lang_changed
      flash[:error] = "Can’t change the form because the semester is critical." if form_changed
      return true
    end
    false
  end

  # Checks if the semester actually has the form and if that form
  # actually offers the language selected. Will report any errors.
  def form_lang_combo_valid?
    # if the semester is critical, these fields will not be submitted.
    # supply them from the database instead.
    if @course
      params[:course][:form_id] ||= @course.form.id if @course.form
      params[:course][:language] ||= @course.language
      params[:course][:semester_id] ||= @course.semester.id if @course.semester
    end

    # check semester has form
    s = Semester.find(params[:course][:semester_id])
    f = Form.find(params[:course][:form_id])

    unless s && f
      flash[:error] = "Selected semester or form not found."
      return false
    end

    unless s.forms.map { |f| f.id }.include?(params[:course][:form_id].to_i)
      flash[:error] = "Form “#{f.name}” (id=#{f.id}) is not " \
                        + "available for semester “#{s.title}”"
      return false
    end

    # check form has language
    l = params[:course][:language]
    return true if f.has_language?(l)
    flash[:error] = "There’s no language “#{l}” for form “#{f.name}”"
    false
  end

  caches_page :index, :new, :show, :edit, :preview
  def kill_caches(course = nil)
    logger.info "="*50

    expire_page :action => "index"

    return unless course
    expire_page :action => "edit", :id => course
    expire_page :action => "preview", :id => course
    expire_page :action => "show", :id => course

    # course title and form are listed on the prof’s page.
    course.profs.each do |p|
      logger.info "Expiring profs#show for #{p.surname}"
      expire_page :controller => "profs", :action => "show", :id => p.id
    end

    course.tutors.each do |t|
      logger.info "Expiring tutors#show for #{t.abbr_name}"
      expire_page :controller => "tutors", :action => "show", :id => t.id
    end
    logger.info "Expiring tutors#index"
    expire_page :controller => "tutors", :action => "index"
  end
end

