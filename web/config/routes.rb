# encoding: utf-8

Seee::Application.routes.draw do
  resources :forms

  resources :faculties

  match "/tutors" => "tutors#index"
  resources :courses do
    resources :tutors
    get "/tutors/:id/preview" => "tutors#preview"
    member do
      post "/add_prof" => "courses#add_prof"
      get "/preview" => "courses#preview"
    end
  end

  #~ match 'exit' => 'sessions#destroy', :as => :tutor

  resources :profs

  resources :semesters do
    get "/courses" => "courses#index"
  end

  root :to => "courses#index"

  post "/course_profs/:id/print" => "course_profs#print", :as => :print_course_prof
end
