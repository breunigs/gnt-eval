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
        params[:id] = @form.id
        flash[:notice] = 'Form was successfully created.'

        format.html { redirect_to(@form) }
        format.json {
          form = render_to_string(:partial => "form_basic.html.erb", :locals => {:is_edit => true})
          coll = render_to_string(:partial => "shared/collision_detection.html.erb")
          render :json => {
              :collision => coll,
              :preview => preview_form_path(@form),
              :form => form
            },
            :status => :created,
            :location => @form
        }
      else
        format.html { render :action => "new" }
        format.json { render :json => @form.errors, :status => :unprocessable_entity }
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
        expire_fragment("preview_forms_#{params[:id]}")

        $loaded_yaml_sheets ||= {}
        if $loaded_yaml_sheets.keys.any? { |k| k.is_a?(String) }
          raise "$loaded_yaml_sheets only allows integer keys, but somewhere a string-key got added. Find out where, or you will run into a lot of stale caches."
        end

        $loaded_yaml_sheets[params[:id].to_i] = nil
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
      $loaded_yaml_sheets[params[:id].to_i] = nil
    end

    respond_to do |format|
      flash[:error] = 'Form was critical and has therefore not been destroyed.' if @form.critical?
      format.html { redirect_to(forms_url) }
      format.xml  { head :ok }
    end
  end

  def copy_to_current
    form = Form.find(params[:id])
    terms = Semester.currently_active
    if terms.empty?
      flash[:error] = "No current terms found. Please create them first."
    else
      terms.each do |t|
        if t.forms.any? { |f| f.name == form.title }
          flash[:warning] ||= []
          flash[:warning] << "Could not add #{form.title} to #{t.title} because there is already a form with that name."
          next
        end
        new_form = form.dup
        new_form.semester = t
        if new_form.save
          flash[:notice] ||= []
          flash[:notice] << "Copied #{form.title} to #{t.title}."
        else
          flash[:warning] ||= []
          flash[:warning] << "Could not add #{form.title} to #{t.title} because of some error."
        end
      end
      flash[:warning] *= "; " if flash[:warning].is_a?(Array)
      flash[:notice] *= "; " if flash[:notice].is_a?(Array)
    end

    respond_to do |format|
      flash[:error] = 'Form was critical and has therefore not been destroyed.' if form.critical?
      format.html { redirect_to(forms_url) }
      format.xml  { head :ok }
    end
  end
end
