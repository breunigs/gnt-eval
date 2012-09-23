# encoding: utf-8

Seee::Application.routes.draw do
  resources :forms do
    member do
      get "/copy_to_current" => "forms#copy_to_current"
      get "/preview" => "forms#preview"
    end
  end

  resources :faculties

  match "/tutors" => "tutors#index"
  resources :courses do
    resources :tutors
    get "/tutors/:id/preview" => "tutors#preview", :as => "tutor_preview"
    post "/tutors/:id/result_pdf" => "tutors#result_pdf", :as => "tutor_result_pdf"
    member do
      post "/add_prof" => "courses#add_prof"
      delete "/drop_prof" => "courses#drop_prof"
      get "/preview" => "courses#preview"
      get "/correlate" => "courses#correlate"
    end
  end

  resources :profs

  resources :semesters do
    get "/courses" => "courses#index"
  end

  root :to => "courses#index"

  post "/course_profs/:id/print" => "course_profs#print", :as => :print_course_prof

  # comment image source pass throughs
  get "/pics/:id/download" => "pics#download", :as => :download_pic
  get "/cpics/:id/download" => "cpics#download", :as => :download_cpic


  match "/:cont/:viewed_id/ping/" => "sessions#ping", :as => "viewer_count"
  match "/:cont/:viewed_id/ping/:ident" => "sessions#ping", :as => "ping"
  match "/:cont/:viewed_id/unping/:ident" => "sessions#unping", :as => "unping"
end
