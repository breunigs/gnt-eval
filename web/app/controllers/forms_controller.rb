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

  # GET /forms/new
  # GET /forms/new.xml
  def new
    @form = Form.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @form }
    end
  end

  # GET /forms/1/edit
  def edit
    @form = Form.find(params[:id])
  end

  # POST /forms
  # POST /forms.xml
  def create
    @form = Form.new(params[:form])

    kill_caches

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
  # PUT /forms/1.xml
  def update
    @form = Form.find(params[:id])
    kill_caches @form

    respond_to do |format|
      if @form.critical?
        flash[:error] = 'Form was critical and has therefore not been updated.' if @form.critical?
        format.html { redirect_to(@form) }
        format.xml  { head :ok }
      elsif @form.update_attributes(params[:form])
        flash[:notice] = 'Form was successfully updated.'
        format.html { redirect_to(@form) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @form.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /forms/1
  # DELETE /forms/1.xml
  def destroy
    @form = Form.find(params[:id])
    @form.destroy unless @form.critical?

    kill_caches @form

    respond_to do |format|
      flash[:error] = 'Form was critical and has therefore not been destroyed.' if @form.critical?
      format.html { redirect_to(forms_url) }
      format.xml  { head :ok }
    end
  end

  caches_page :index, :show, :new, :edit
  private
  def kill_caches(form = nil)
    puts "="*50
    puts "Expiring form caches" + (form ? " for #{form.name}" : "")
    expire_page :action => "index"
    expire_page :action => "new"
    if form
      expire_page :action => "show", :id => form
      expire_page :action => "edit", :id => form
      $loaded_yaml_sheets[form.id] = nil if $loaded_yaml_sheets
    end

    # need to expire all edit+new pages, in case a form was added
    if defined? Courses && !Courses.nil?
      Courses.find(:all) do |c|
        puts "Expiring courses#edit+new caches for #{c.title}"
        expire_page :controller => "courses", :action => "edit", :id => c
        expire_page :controller => "courses", :action => "new", :id => c
      end
    end

    return unless form
    form.courses.each do |c|
      puts "Expiring courses#show caches for #{c.title}"
      expire_page :controller => "courses", :action => "show", :id => c
      c.profs.each do |p|
        puts "Expiring profs#edit for #{p.surname}"
        expire_page :controller => "profs", :action => "edit", :id => p
      end
    end
  end
end
