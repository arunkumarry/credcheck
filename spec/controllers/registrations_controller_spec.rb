require 'rails_helper'

RSpec.describe RegistrationsController, type: :controller do
  # RegistrationsController allows unauthenticated access (no auth guard).
  # It handles new user sign-up.

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end

    it "renders the new template" do
      get :new
      expect(response).to render_template(:new)
    end

    it "assigns a new User to @user" do
      get :new
      expect(assigns(:user)).to be_a_new(User)
    end
  end

  describe "POST #create" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            first_name:            "Alice",
            last_name:             "Smith",
            email_address:         "alice@example.com",
            password:              "password123",
            password_confirmation: "password123"
          }
        }
      end

      it "creates a new User in the database" do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)
      end

      it "starts a session for the new user (creates a Session record)" do
        expect {
          post :create, params: valid_params
        }.to change(Session, :count).by(1)
      end

      it "redirects to the root/after-authentication URL" do
        post :create, params: valid_params
        # after_authentication_url falls back to root_url when there is no
        # stored return-to URL in the session.
        expect(response).to redirect_to(root_url)
      end
    end

    context "with invalid parameters — passwords do not match" do
      let(:invalid_params) do
        {
          user: {
            first_name:            "Bob",
            last_name:             "Jones",
            email_address:         "bob@example.com",
            password:              "password123",
            password_confirmation: "wrong"
          }
        }
      end

      it "does NOT create a new User" do
        expect {
          post :create, params: invalid_params
        }.not_to change(User, :count)
      end

      it "re-renders the new template" do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it "returns 422 Unprocessable Entity" do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "assigns the unsaved user to @user so the form can repopulate" do
        post :create, params: invalid_params
        expect(assigns(:user)).to be_a(User)
        expect(assigns(:user)).not_to be_persisted
      end
    end

    context "with a duplicate email address" do
      before { create(:user, email_address: "dup@example.com") }
      let(:duplicate_params) do
        {
          user: {
            first_name:            "Dave",
            last_name:             "Green",
            email_address:         "dup@example.com",
            password:              "password123",
            password_confirmation: "password123"
          }
        }
      end

      it "does NOT create an additional User" do
        expect {
          post :create, params: duplicate_params
        }.not_to change(User, :count)
      end

      it "re-renders the new template with 422" do
        post :create, params: duplicate_params
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
