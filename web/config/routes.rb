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
    get "/emergency_printing" => "courses#emergency_printing"
    post "/emergency_printing" => "courses#emergency_printing"
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

  resources :terms do
    get "/courses" => "courses#index"
  end

  root :to => "courses#index"

  post "/course_profs/:id/print" => "course_profs#print", :as => :print_course_prof

  # comment image source pass throughs
  get "/pics/:id/download" => "pics#download", :as => :download_pic
  get "/cpics/:id/download" => "CPics#download", :as => :download_cpic


  get "/hitme" => "hitmes#overview"
  get "/hitme/assign_work" => "hitmes#assign_work"
  get "/hitme/cookie_test" => "hitmes#cookie_test"
  get "/hitme/active_users" => "hitmes#active_users"
  post "/hitme/preview_text" => "hitmes#preview_text"
  post "/hitme/save_comment" => "hitmes#save_comment"
  post "/hitme/save_combination" => "hitmes#save_combination"
  post "/hitme/save_final_check" => "hitmes#save_final_check"


  match "/:cont/:viewed_id/ping/" => "sessions#ping", :as => "viewer_count"
  match "/:cont/:viewed_id/ping/:ident" => "sessions#ping", :as => "ping"
  match "/:cont/:viewed_id/unping/:ident" => "sessions#unping", :as => "unping"
end
