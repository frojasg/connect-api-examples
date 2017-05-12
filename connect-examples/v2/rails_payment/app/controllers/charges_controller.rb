PRODUCT_COST = {
  "001" => 100,
  "002" => 4900,
  "003" => 500000
}

class ChargesController < ApplicationController

  def charge_card
    #check if product exists
    if !PRODUCT_COST.has_key? params[:product_id]
      render json: {:status => 400, :errors => [{"detail": "Product unavailable"}]  }
      return
    end

    amount = PRODUCT_COST[params[:product_id]]
    card_nonce = params[:nonce]

    begin
      gateway = gateway(locations.locations[1].id)
      resp = gateway.purchase(amount, card_nonce)

    rescue SquareConnect::ApiError => e
      puts 'Error encountered while charging card:'
      puts e.message
      render json: {:status => 400, :errors => JSON.parse(e.response_body)["errors"]  }
      return
    end
    puts resp

    data = {
      amount: amount,
      user: {
        name: params[:name],
        street_address_1: params[:street_address_1],
        street_address_2: params[:street_address_2],
        state: params[:state],
        zip: params[:zip],
        city: params[:city]
      },
      card: resp.params['transaction']['tenders'].first['card_details']['card']
    }

    # send receipt email to user
    ReceiptMailer.charge_email(params[:email], data).deliver_now if Rails.env == "development"

    render json: {:status => 200}
  end

  private

  def locations
    # The SDK throws an exception if a Connect endpoint responds with anything besides 200 (success).
    # This block catches any exceptions that occur from the request.
    locationApi = SquareConnect::LocationApi.new()
    locationApi.list_locations(Rails.application.secrets.square_access_token)
  end

  def gateway(location_id)
    credentials = {
      login: Rails.application.secrets.square_application_id,
      password: Rails.application.secrets.square_access_token,
      location_id: location_id,
      test: false
    }
    ActiveMerchant::Billing::SquareGateway.new(credentials)
  end
end
