# initialise list of selected tracks
tracksSelected <- reactiveValues(tracks = c())

# remember which layers have been loaded
tracksLayers <- reactiveValues(loaded = c())

# trips available based on user, dates and vessels selected
tripsAvailable <- reactiveValues(data = NULL)

# remember previous value of map type
oldMapType <- reactiveVal('tracks')

# names of map groups
tracksOverlayGroups <- c(
#  'bathymetry' = 'Bathymetry',
  'substrate' = 'Substrate',
  'smr' = 'Scottish Marine Regions',
  'rifgs' = 'RIFGs',
  '3mile' = '3 mile limit',
  '6mile' = '6 mile limit'#,
#  'observations' = 'Wildlife observations'
  )
tracksBaseGroups <- c(
  'osm' = 'OSM (MPAs, 12 mile limit)',
  'bathymetry' = 'Bathymetry'
  )

# panes and their z-Indexes
tracksPanes <- c(
#  'bathymetry' = 405,
  'idhabitat' = 410,
  'idregions' = 415,
  'idrifg' = 416,
  'idthree' = 420,
  'idsix' = 421,
  'tracks' = 450#,
#  'observations' = 460
  )

tracksFishingEventOptions <- c(
  'String haul' = 'StringHaul',
  'String shoot' = 'StringShoot',
  'Pot' = 'Pot'
  )

# clear tracks from map
clearTracks <- function(mapType, trips) {
  #{{{
  map <- leafletProxy("tracksMap")
  
  for (t in trips) {
    map <- clearGroup(map, paste0(mapType, t))
  }
}
#}}}

# plot events on map
mapEvents <- function(events) { #{{{
  if (length(events) == 0) {
    return()
  }

  # get map proxy
  map <- leafletProxy("tracksMap")
  
  pal <- colorFactor("RdYlBu", events$activity_name)
  
  # add legend for events
  map <- clearControls(map)
  map <- addLegend(map, 'bottomright', pal=pal, 
    values=events$activity_name, opacity=1)
  
  for (trip in split(events, list(events$trip_id), drop=TRUE)) {
    # use same group as for trip tracks
    group <- paste0('trip', trip[1,]$trip_id)
    
    map <- addCircleMarkers(map,
      lat=trip$latitude, lng=trip$longitude, 
      radius=15, stroke=F,
      color=pal(trip$activity_name),
      fillOpacity=1, group=group,
      clusterOptions=markerClusterOptions())
  }
}
#}}}

# plot latest points for vessels on map
mapLatestPoints <- function(latestPoints) { #{{{
  # mark latest points for vessels
  if (length(latestPoints) == 0) {
    return()
  }

  # get map proxy
  map <- leafletProxy("tracksMap")

  map <- addMarkers(map,
    data=latestPoints,
    lat=~latitude, lng=~longitude,
    label=~paste(vessel_name, ' ', time_stamp),
    group=~paste0('tracks', trip_id))
}
#}}}

# draw tracks as lines on map
mapTrackLinesSP <- function(tracks) { #{{{
  # have tracks, so add them to map
  if (length(tracks) == 0) {
    return()
  }

  # get map proxy
  map <- leafletProxy("tracksMap")
  
  # colour by vessel when there are multiple vessels, else by trip
  if (length(unique(tracks$vessel_id)) > 1) {
    tracks$colour <- as.numeric(factor(tracks$vessel_id))
  } else {
    tracks$colour <- as.numeric(factor(tracks$trip_id))
  }

  # different colours for different vessels' tracks
  pal <- colorFactor("RdYlBu", tracks$colour)
  
  # split tracks into trips
  map <- addPolylines(map,
    data=tracks$geom,
    color=pal(tracks$colour),
    fillOpacity=1, 
    group=paste0('tracks', tracks$trip_id),
    options=pathOptions(pane="tracks"))
}
#}}}

mapTrackDotsSP <- function(tracks) { #{{{
  # have tracks, so add them to map
  if (length(tracks) == 0) {
    return()
  }

  # get map proxy
  map <- leafletProxy("tracksMap")
  
  pal <- colorFactor(c('blue', 'red'), c(1, 2))

  map <- addCircleMarkers(map,
    data=tracks$geom,
    group=paste0('analysed_tracks', tracks$trip_id),
    radius=3, stroke=F,
    color=pal(tracks$activity),
    fillOpacity=1, options=pathOptions(pane="tracks"))
}
#}}}

# pull together data for tracks, latest points and events
# and draw them on map
mapTracksAndEvents <- function(newTracks) { #{{{
  # have new tracks to fetch from database
  if (length(newTracks) == 0) {
    return()
  }
  
  # join selected tracks and get data
  trkArr <- sprintf("{%s}", paste(newTracks, collapse=","))
  
  # unanalysed tracks as lines
  if (input$tracksMapType == 'tracks') {
    tracks <- dbProcST('tracksFromTripsSP', 
      list(user$id, sprintf("'%s'", trkArr)))
    
    if (length(tracks) == 0) {
      return()
    }
    
    mapTrackLinesSP(tracks)
  }
  # analysed tracks as dots
  else if (input$tracksMapType == 'analysed_tracks') {
    tracks <- dbProcST('analysedTracksFromTripsSP', 
      list(user$id, sprintf("'%s'", trkArr)))
    
    if (length(tracks) == 0) {
      return()
    }
    
    mapTrackDotsSP(tracks)
  }
  
  # get latest points (today) for vessels (in any selected trips)
  latestPoints <- dbProc('latestPoints', list(user$id, trkArr))
  
  mapLatestPoints(latestPoints)
  
  # have fishing events
#  if (!is.null(input$tracksEvents)) {
#    eventsArr <- sprintf('{%s}', paste(input$tracksEvents, collapse=","))
#    events <- dbProc('eventsFromTrips', list(user$id, trkArr, eventsArr))
#    
#    mapEvents(events)
#  }
}
#}}}

trackDataDownload <- function() { #{{{
  # get trips in the table and keep just the ones selected in table
  data <- tripsAvailable$data
  if (length(data) == 0) {
    return()
  }
  
  data <- data[input$tracksTrips_rows_selected,]
  selectedTracks <- data$trip_id
  
  dbProc('trackDataFromTrips', list(user$id, getArray(selectedTracks)))
}
#}}}

# get first/last dates of tracks for given vessel
tracksDates <- reactive({
    #{{{
    dbProc('datesForTracks', list(user$id, getArray(input$tracksVessels)))
  })
#}}}

# get track (when hauling) using vessels and dates for heat map
tracksHeatSP <- reactive({ 
    #{{{
    # need dates
    dates <- getDateRange(input$tracksDates)
    if (is.null(dates)) {
      return()
    }

    dbProcST('heatMapDataSP', 
      list(user$id, 
        sprintf("'%s'", getArray(input$tracksVessels)),
        sprintf("'%s'", dates[1]), 
        sprintf("'%s'", dates[2])))
  })
#}}}

# get track using vessels and dates for heat map (for fishers)
tracksFisherHeat <- reactive({ 
    #{{{
    # need dates
    dates <- getDateRange(input$tracksDates)
    if (is.null(dates)) {
      return()
    }

    dbProc('heatMapDataFisher', 
      list(user$id, 
        getArray(input$tracksVessels), 
        dates[1], dates[2]))
  })
#}}}

# get grids visited
tracksGridsSP <- reactive({ 
    #{{{
    # need dates
    dates <- getDateRange(input$tracksDates)
    if (is.null(dates)) {
      return()
    }

    dbProcST('revisitsMapDataSP', 
      list(user$id, 
        sprintf("'%s'", getArray(input$tracksVessels)), 
        sprintf("'%s'", dates[1]), 
        sprintf("'%s'", dates[2])))
  })
#}}}

# get trips made by vessel between dates (all users)
observeEvent({
    input$tracksDates
    input$tracksVessels
  }, {
    #{{{
    # need dates
    dates <- getDateRange(input$tracksDates)
    if (is.null(dates) || is.na(dates)) {
      return()
    }

    # get trips
    tripsAvailable$data <- dbProc('tripEstimates', 
      list(user$id, 
        getArray(input$tracksVessels), 
        dates[1], dates[2]))
  }, ignoreNULL=FALSE)
#}}}


# are estimates available for user's tracks
estimatesAvailable <- reactive({
    #{{{
    dbProc('trackDataAvailable', list(user$id))
  })
#}}}

# are events available for user's tracks
eventsAvailable <- reactive({
    #{{{
    dbProc('fishingEventsAvailable', list(user$id, getArray(input$tracksVessels)))
  })
#}}}

# output trips (all users except fishers)
output$tracksTrips <- DT::renderDataTable({ 
    #{{{
    if (is.null(tripsAvailable$data)) {
      return()
    }
    
    datatable(tripsAvailable$data,
      colnames=c('Trip ID', 'Trip', 'Creels (low)*', 'Creels (high)*', 'Distance (km)*'),
      rownames=FALSE, 
      options=list(columnDefs=list(list(visible=FALSE, targets=c(0))))
      )
  })
#}}}

# output trips (just fishers)
output$tracksFisherTrips <- DT::renderDataTable({ 
    #{{{
    if (is.null(tripsAvailable$data)) {
      return()
    }
    
    datatable(tripsAvailable$data[c(1,2)],
      colnames=c('Trip ID', 'Trip'),
      rownames=FALSE,
      options=list(columnDefs=list(list(visible=FALSE, targets=c(0))))
      )
  })
#}}}

# output vessels as select control
output$tracksVessels <- renderUI({ 
    #{{{
    vessels <- dbProcNamed('trackVessels', list(user$id), 'vessel_id', 'vessel_pln')
    
    selectInput('tracksVessels', 'Vessels', vessels, multiple=TRUE)
  })
#}}}

# output dates as date range control
output$tracksDaterange <- renderUI({ 
    #{{{
    dateArr <- tracksDates() # get dates from reactive function
    dateRangeInput('tracksDates', 'Between these dates', 
      start=dateArr[[1]], end=dateArr[[2]], format='dd-mm-yyyy')
  })
#}}}

# type of map (for all except fishers)
output$tracksMapType <- renderUI({ 
    #{{{
    # initial choices
    choices <- c('Track data' = 'tracks', 
      'Analysed track data' = 'analysed_tracks')
    
    # find out whether track estimates are available
    estimates <- estimatesAvailable()
    if (estimates[1]$estimates == 1) {
      choices <- c(choices, 
        'Heat map showing time spent hauling' = 'heat',
        'Revisits while hauling' = 'revisits')
    }
    
    radioButtons('tracksMapType', 'Type of map',
      choices)
  })
#}}}

# type of map (just for fishers)
output$tracksFisherMapType <- renderUI({ 
    #{{{
    # choices
    choices <- c('Track data' = 'tracks',
      'Heat map showing time spent' = 'heat_all')
    
    radioButtons('tracksMapType', 'Type of map',
      choices)
  })
#}}}

# fishing event options
output$tracksFishingEvents <- renderUI({
    #{{{
    # get events for user's tracks
    events <- eventsAvailable()
    # create named vector of available events
    choices = tracksFishingEventOptions[unname(tracksFishingEventOptions) %in% events$event]
    
    checkboxGroupInput("tracksEvents", "Fishing events to display",
      choices = choices)
  })
#}}}

# button for clearing tracks has been clicked
observeEvent(input$clearTracks, {
    #{{{
    # get table proxy and select NULL rows
    table <- dataTableProxy('tracksTrips')
    selectRows(table, NULL)
  })
#}}}

# button for clearing tracks has been clicked (fishers)
observeEvent(input$clearFisherTracks, {
    #{{{
    # get table proxy and select NULL rows
    table <- dataTableProxy('tracksFisherTrips')
    selectRows(table, NULL)
  })
#}}}

# map showing tracks, use ignoreNULL=F so that event is observed even when no rows selected
observeEvent({
    input$tracksTrips_rows_selected
    input$tracksMapType
  },
  ignoreNULL=FALSE, { 
    #{{{
    req(user$role)
    if (user$role == 'fisher') {
      return()
    }
    
    # get trips in the table and keep just the ones selected in table
    data <- tripsAvailable$data
    if (length(data) == 0) {
      return()
    }
    
    data <- data[input$tracksTrips_rows_selected,]
    selectedTracks <- data$trip_id
    
    # not map showing tracks
    if (is.null(input$tracksMapType) || (input$tracksMapType != 'tracks' && input$tracksMapType != 'analysed_tracks')) {
      clearTracks(oldMapType(), selectedTracks) # clear all tracks
      
      oldMapType(input$tracksMapType) # remember map type
      
      # changed map type
    } else if (input$tracksMapType != oldMapType()) {
      clearTracks(oldMapType(), selectedTracks) # clear all tracks
      mapTracksAndEvents(selectedTracks) # display all tracks using new type
      oldMapType(input$tracksMapType) # remember map type
      
      # selected rows changed
    } else {
      # get trips no longer selected
      clearTracks(oldMapType(),
        tracksSelected$tracks[!(tracksSelected$tracks %in% selectedTracks)])
      # only get tracks for trips not already selected
      mapTracksAndEvents(selectedTracks[!(selectedTracks %in% tracksSelected$tracks)])
    }
    
    tracksSelected$tracks <- selectedTracks # remember new selected tracks
  })
#}}}

# map showing tracks (for fishers), use ignoreNULL=F so that event is observed even when no rows selected
observeEvent({
    input$tracksFisherTrips_rows_selected
    input$tracksMapType
  },
  ignoreNULL=FALSE, { 
    #{{{
    req(user$role)
    if (user$role != 'fisher') {
      return()
    }
    
    # get trips in the table and keep just the ones selected in table
    data <- tripsAvailable$data
    if (length(data) == 0) {
      return()
    }
    
    data <- data[input$tracksFisherTrips_rows_selected,]
    selectedTracks <- data$trip_id
    
    # not map showing tracks
    if (is.null(input$tracksMapType) || input$tracksMapType != 'tracks') {
      clearTracks(oldMapType(), selectedTracks) # clear all tracks
      oldMapType(input$tracksMapType) # remember map type
      
      # selected rows changed
    } else {
      clearTracks(oldMapType(),
        tracksSelected$tracks[!(tracksSelected$tracks %in% selectedTracks)])
      # only get tracks for trips not already selected
      mapTracksAndEvents(selectedTracks[!(selectedTracks %in% tracksSelected$tracks)])
    }
    
    tracksSelected$tracks <- selectedTracks # remember new selected tracks
  })
#}}}

# group control changed
observeEvent(input$tracksMap_groups, {
    #{{{
    # get map proxy
    map <- leafletProxy("tracksMap")
    
    # substrate layer for track map
    group = tracksOverlayGroups[['substrate']]
    if (group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
      withProgress(message='Loading substrate data', value=0, {
          habitat <- readRDS("habitat.rds")
          
          factpal <- colorFactor(brewer.pal(n=11, name="Spectral") , habitat$folk_d50) 
          p_popup <- paste0("<strong>substrate: </strong>", habitat$folk_d50)
          
          map <- addPolygons(map, data=habitat, 
            stroke = FALSE, fillColor = ~factpal(folk_d50), 
            fillOpacity = 0.5, smoothFactor = 0.5,  popup = p_popup, group=group,
            options=pathOptions(pane="idhabitat"))
          
          tracksLayers$loaded <- c(tracksLayers$loaded, group)
        })
    }

    # Scottish Marine Regions
    group = tracksOverlayGroups[['smr']]
    if(group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
      regions <- dbProcST('scottishMarineRegions', list())
      p_popup <- paste0("<strong>region: </strong>", regions$objnam)
      
      map <- addPolygons(map, data=regions,
        fill = T, weight = 1.5, color = "yellow", 
        group = group, smoothFactor = 0.7, 
        popup=p_popup, options=pathOptions(pane="idregions"))
      
      tracksLayers$loaded <- c(tracksLayers$loaded, group)
    }
    
    # 3 mile limit
    group = tracksOverlayGroups[['3mile']]
    if(group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
      limitData <- dbProcST('threeMileLimit', list())
      map <- addPolygons(map, data=limitData, 
        fill = F, weight = 1, color = "black", group = group,
        options=pathOptions(pane="idthree"))
      
      tracksLayers$loaded <- c(tracksLayers$loaded, group)
    }

    # 6 mile limit
    group = tracksOverlayGroups[['6mile']]
    if(group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
      limitData <- dbProcST('sixMileLimit', list())
      map <- addPolygons(map, data=limitData, 
        fill = F, weight = 1, color = "blue", group = group,
        options=pathOptions(pane="idsix"))
      
      tracksLayers$loaded <- c(tracksLayers$loaded, "group")
    }
    
    # RIFGs
    group = tracksOverlayGroups[['rifgs']]
    if(group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
      rifg <- dbProcST('RIFGs', list())
      n <- length(unique(rifg$rifg))
      palette <- viridis(n, option="D")
      set.seed(15887)
      rifg$col <- palette
      p_popup <- paste0("<strong>region: </strong>", rifg$rifg)
      
      map <- addPolygons(map, data=rifg, 
        fill = T, weight = 0, fillOpacity = 0.5, color = ~col, 
        group = group, smoothFactor = 0.7, 
        popup = p_popup, options=pathOptions(pane="idrifg"))
      
      tracksLayers$loaded <- c(tracksLayers$loaded, group)
    }

    # observations from app
#    group = tracksOverlayGroups[['observations']]
#    if (group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
#      data <- dbProc('geographyObservations', list())
#      pal <- colorFactor("RdYlBu", data$animal_group)
#      
#      map <- addCircleMarkers(map, lat=data$latitude, lng=data$longitude, 
#        radius=15, color=pal(data$animal_group), stroke=F, fillOpacity=0.8, 
#        popup=paste("<strong>", data$animal_name, "</strong><br/>", data$observation_count),
#        group=group)
#      
#      map <- addLegend(map, pal=pal, values=data$animal_group, title="Animals observed", group=group)
#      
#      tracksLayers$loaded <- c(tracksLayers$loaded, group)
#    }

    # bathymetry
#    group = tracksOverlayGroups[['bathymetry']]
#    if (group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
#      withProgress(message='Loading bathymetry data', value=0, {
#          data <- raster('bathymetry.nc')
#          depths <- values(data)
#          depths <- depths[depths < 0]
#          pal <- colorBin(palette='Blues', domain=depths, 
#            bins=c(0, -5, -10, -15, -20, -25, -50, -75, -100, -2000), 
#            na.color = "transparent")
#          
#          map <- addRasterImage(map, data,
#            colors=pal, opacity=0.5,
#            group=group)
#          
#          map <- addLegend(map, pal=pal, values=depths, title="Depth (m)", group=group)
#          
#          tracksLayers$loaded <- c(tracksLayers$loaded, group)
#        })
#    }
    
    # OSM base layer
    group = tracksBaseGroups[['osm']]
    if (group %in% input$tracksMap_groups && !("group" %in% tracksLayers$loaded)) {
      map <- addTiles(map, group=group,
        options=tileOptions(updateWhenZooming=F, updateWhenIdle=T))
      
      tracksLayers$loaded <- c(tracksLayers$loaded, group)
    }
    
    # Bathymetry base layer
#    group = tracksBaseGroups[['bathymetry']]
#    if (group %in% input$tracksMap_groups && !(group %in% tracksLayers$loaded)) {
#      map <- addProviderTiles(map, providers$Esri.OceanBasemap, group=group,
#        options=providerTileOptions(updateWhenZooming=F, updateWhenIdle=T))
#      
#      tracksLayers$loaded <- c(tracksLayers$loaded, group)
#    }
    
  })
#}}}

# heat map showing time spent hauling
observe({ 
    #{{{
    # get map proxy
    map <- leafletProxy("tracksMap")
    map <- clearGroup(map, group="heat")
    
    if (is.null(input$tracksMapType) || input$tracksMapType != 'heat') {
      return()
    }

    # clear any tracks
    for (track in tracksSelected$tracks) {
      map <- clearGroup(map, group=track)
    }

    table = dataTableProxy('tracksTrips')
    selectRows(table, NULL)

    tracks <- tracksHeatSP()
    
    if (length(tracks) > 0) {
      map <- addHeatmap(map, 
        group="heat", blur=25, max=0.1, radius=15, 
        data=tracks$geog)
    }
  })
#}}}

# heat map showing time spent (for fishers)
observe({ 
    #{{{
    # get map proxy
    map <- leafletProxy("tracksMap")
    map <- clearGroup(map, group="heat_all")
    
    if (is.null(input$tracksMapType) || input$tracksMapType != 'heat_all') {
      return()
    }

    # clear any tracks
    for (track in tracksSelected$tracks) {
      map <- clearGroup(map, group=track)
    }

    table = dataTableProxy('tracksFisherTrips')
    selectRows(table, NULL)

    tracks <- tracksFisherHeat()
    
    if (length(tracks) > 0) {
      map <- addHeatmap(map, lng=~long, lat=~lat, group="heat", blur=25, max=0.1, radius=15, data=tracks)
    }
  })
#}}}

# map showing revisits
observe({ 
    #{{{
    # get map proxy
    map <- leafletProxy("tracksMap")
    map <- clearGroup(map, group="revisits")
    map <- clearControls(map)
    
    if (is.null(input$tracksMapType) || input$tracksMapType != 'revisits') {
      return()
    }

    # clear any tracks
    for (track in tracksSelected$tracks) {
      map <- clearGroup(map, group=track)
    }
    
    table <- dataTableProxy('tracksTrips')
    selectRows(table, NULL)
    
    grids <- tracksGridsSP()
    
    if (length(grids) > 0) {
      pal <- colorNumeric("viridis", grids$counts)
      
      map <- addPolygons(map, 
        fillColor=pal(grids$counts), fillOpacity=0.8, 
        stroke=FALSE, data=grids, group="revisits")
      
      map <- addLegend(map, position="topright", 
        pal=pal, values=grids$count, title="# hauling visits")
    }
  })
#}}}

# output map
output$tracksMap <- renderLeaflet({ 
    #{{{
    map <- leaflet(options = leafletOptions(preferCanvas = TRUE))
    map <- setView(map, -4, 57, zoom=7) # centre on Scotland
    map <- addScaleBar(map)
    
    # add tiles
    map <- addTiles(map, options=tileOptions(updateWhenZooming=F, updateWhenIdle=T))
    
    map <- addLayersControl(map,
#      baseGroups=unname(tracksBaseGroups),
      overlayGroups=unname(tracksOverlayGroups),
      options = layersControlOptions(collapsed = FALSE, autoZIndex=FALSE))
    
    # hide overlay groups initially
    for (g in unname(tracksOverlayGroups)) {
      map <- hideGroup(map, group=g)
    }
    
    # map panes to control what is on top of what else
    for (p in names(tracksPanes)) {
      map <- addMapPane(map, p, zIndex=tracksPanes[[p]])
    }
    
    map
  })
#}}}

# download trip/track data
output$tripsDownload <- downloadHandler(
  #{{{
  filename = 'trips.csv',
  
  content = function(file) {
    write.csv(tripsAvailable$data, file)
  }
  )
#}}}

output$tracksDownload <- downloadHandler(
  #{{{
  filename = 'tracks.csv',
  
  content = function(file) {
    write.csv(trackDataDownload(), file)
  }
  )
#}}}

output$tripssFisherDownload <- downloadHandler(
  #{{{
  filename = 'trips.csv',
  
  content = function(file) {
    write.csv(tripsAvailable$data[c(1,2)], file)
  }
  )
#}}}
