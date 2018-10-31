$ ->
  ($ '#country_based').click ->
    show_country()

  ($ '#state_based').click ->
    show_state()

  ($ '#city_based').click ->
    show_city()

  if ($ '#country_based').is(':checked')
    show_country()
  else if ($ '#state_based').is(':checked')
    show_state()
  else if ($ '#city_based').is(':checked')
    show_city()
  # else
  #   show_state()
  #   ($ '#state_based').click()



show_country = ->
  ($ '#state_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#state_members').hide()

  ($ '#city_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#city_members').hide()

  ($ '#zone_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#zone_members').hide()
  ($ '#country_members :input').each ->
    ($ this).prop 'disabled', false

  ($ '#country_members').show()

show_state = ->
  ($ '#country_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#country_members').hide()

  ($ '#city_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#city_members').hide()

  ($ '#zone_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#zone_members').hide()
  ($ '#state_members :input').each ->
    ($ this).prop 'disabled', false

  ($ '#state_members').show()

show_city = ->
  ($ '#country_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#country_members').hide()

  ($ '#state_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#state_members').hide()

  ($ '#zone_members :input').each ->
    ($ this).prop 'disabled', true

  ($ '#zone_members').hide()

  ($ '#city_members :input').each ->
    ($ this).prop 'disabled', false

  ($ '#city_members').show()
