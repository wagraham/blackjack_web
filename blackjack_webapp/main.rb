require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'random_string_here' 

BLACKJACK_AMOUNT = 21 #constants, so that you don't have to manually change each entry of 21, if you want blackjack to be 23, e.g.
DEALER_MIN_HIT = 17
INITIAL_POT_AMOUNT = 500

helpers do
  def calculate_total(cards)
    arr = cards.map{|element| element[1]}
    
    total = 0
    arr.each do |a|
      if a == "A"
        total += 11
      else
        total += a.to_i == 0 ? 10 : a.to_i
      end
    end

    arr.select{|element| element == "A"}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= 10
    end

     total
  end

  def card_image(card)# ['H', '4']
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end
    
    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"

  end

  def winner!(msg)
    @play_again = true
    @winner = "<strong>#{session[:player_name]} wins!</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    session[:player_pot] = session[:player_pot] + session[:player_bet]
  end

  def loser!(msg)
    @play_again = true
    @loser = "<strong>#{session[:player_name]} loses.</strong> #{msg}"
    @show_hit_or_stay_buttons = false
    session[:player_pot] = session[:player_pot] - session[:player_bet]
  end

  def tie!(msg)
    @play_again = true
    @winner = "<strong> It's a tie!</strong> #{msg}"
    @show_hit_or_stay_buttons = false
  end

end


before do #run before every single following actions
  @show_hit_or_stay_buttons = true #else, no buttons would show up without instance variable set up before action
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_pot] = INITIAL_POT_AMOUNT
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "Name entry required."
    halt erb(:new_player) #halt stops action and does what following cmd says
  end
  
  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  session[:player_bet] = nil #so if a person plays again (cf. game.erb), then the amount will be reset
  erb :bet
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0   #calling name of in input; to_i because forms submit strintgs
    @error = "Please, place a bet."
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot] #we've set integer for pot, so no need for to.i
    @error = "Bet amount cannot be greater than the amount in your pot ($#{session[:player_pot]})."
    halt erb(:bet)  
  else #good path
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]
  #deck in session.
  suits = ['H', 'D', 'C', 'S']  
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!
  
  #deal cards
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])  
  if player_total == BLACKJACK_AMOUNT
    winner!("#{session[:player_name]} hits blackjack!") 
  elsif player_total > BLACKJACK_AMOUNT
    loser!("Sorry, it looks like #{session[:player_name]} busted at #{player_total}.")
  end
  erb :game, layout: false # renders game template, rather than going back to /game which would reset the game. 
end

post '/game/player/stay' do
  @success = "#{session[:player_name]} has chosen to stay."
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false #to turn hit/stay buttons off


  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMOUNT
    loser!("Sorry, dealer hit blackjack.")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner!("Congratulations, dealer busted at #{dealer_total}. You win.")
  elsif dealer_total >= DEALER_MIN_HIT #17-20
    #dealer stays
    redirect '/game/compare'
  else 
    #dealer hits
    @show_dealer_hit_button = true     
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_or_stay_buttons = false
  
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}.")
  else
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total}.")
  end
    
  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end


#post '/set_name' do
  #session[:player_name] = params[:player_name]
  #redirect '/game'
#end

#get '/game' do

#session[:deck] = @deck[:deck]

#end





