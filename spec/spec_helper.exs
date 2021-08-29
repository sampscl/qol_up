ESpec.configure fn(config) ->

  Application.ensure_all_started(:briefly)

  config.before fn(tags) ->
    {:shared, tags: tags}
  end

  config.finally fn(_shared) ->
    :ok
  end
end
