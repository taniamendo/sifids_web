introTab <- tabPanel("Introduction",
  fluidPage(
    title="Introducing the Scottish Inshore Fisheries Integrated Data System (SIFIDS) Marine Database",
    fluidRow(
      h1("Introducing the Scottish Inshore Fisheries Integrated Data System (SIFIDS) Marine Database"),
      h3("Please note that this is a prototypic web portal created for the SIFIDS project. Some of its original functionality has been removed and the portal is for demonstration purposes only."),
      p("Developed by Seascope Research Ltd and University of St Andrews as part of the SIFIDS Project")
      ),
    fluidRow(
      column(4, imageOutput('marine_scotland', height="180px")), 
      column(4, imageOutput('emff', height="180px")),
      column(4, imageOutput('seascope', height="180px"))
      ),
    fluidRow(
      column(6, imageOutput('sifids', height="180px")), 
      column(6, imageOutput('st_andrews', height="180px"))
      )
    )
  )
