# encoding: utf-8

class FormsController < ApplicationController
  # GET /forms
  # GET /forms.xml
  def index
    @forms = Form.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @forms }
    end
  end

  # GET /forms/1
  # GET /forms/1.xml
  def show
    @form = Form.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @form }
    end
  end

  def preview
    @form = Form.find(params[:id])
    # this renders the small partial preview view only. shared/preview
    # will invoke form_helpers.rb#texpreview.
    render :partial => "shared/preview", :locals => {:text => nil}
  end

  def new
    @form = Form.new
    $emptyFormYaml ||= File.read(File.join(GNT_ROOT, "doc", "example_forms", "empty.yaml"))
    @form.content = $emptyFormYaml
  end

  # GET /forms/1/edit
  def edit
    @form = Form.find(params[:id])
  end

  # POST /forms
  # POST /forms.xml
  def create
    @form = Form.new(params[:form])

    respond_to do |format|
      if @form.save
        flash[:notice] = 'Form was successfully created.'
        format.html { redirect_to(@form) }
        format.xml  { render :xml => @form, :status => :created, :location => @form }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @form.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /forms/1
  def update
    @form = Form.find(params[:id])

    respond_to do |format|
      if @form.critical?
        flash[:error] = 'Form was critical and has therefore not been updated.'
        format.html { redirect_to(@form) }
        format.json { render json: flash[:error], status: :unprocessable_entity }
      elsif @form.update_attributes(params[:form])
        $loaded_yaml_sheets[params[:id]] = nil
        format.html { redirect_to @form, notice: 'Form was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render json: @form.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /forms/1
  # DELETE /forms/1.xml
  def destroy
    @form = Form.find(params[:id])
    unless @form.critical?
      @form.destroy
      $loaded_yaml_sheets[params[:id]] = nil
    end

    respond_to do |format|
      flash[:error] = 'Form was critical and has therefore not been destroyed.' if @form.critical?
      format.html { redirect_to(forms_url) }
      format.xml  { head :ok }
    end
  end

  def copy_to_current
    form = Form.find(params[:id])
    sems = Semester.currently_active
    if sems.empty?
      flash[:error] = "No current semesters found. Please create them first."
    else
      sems.each do |s|
        if s.forms.map { |f| f.name }.include?(form.title)
          flash[:warning] = "Could not add #{form.title} to #{s.title} because there is already a form with that name."
          next
        end
        new_form = form.clone
        new_form.semester = s
        if new_form.save
          flash[:notice] = "Copied #{form.title} to #{s.title}."
        else
          flash[:warning] = "Could not add #{form.title} to #{s.title} because of some error."
        end
      end
    end

    respond_to do |format|
      flash[:error] = 'Form was critical and has therefore not been destroyed.' if form.critical?
      format.html { redirect_to(forms_url) }
      format.xml  { head :ok }
    end
  end
end
