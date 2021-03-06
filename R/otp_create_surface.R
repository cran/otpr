#' Creates a travel time surface (OTPv1 only).
#'
#' Creates a travel time surface for an origin point. A surface contains the travel time
#' to every geographic coordinate that can be reached from that origin (up to a hard coded
#' limit in OTP of 120 minutes). Optionally, the surface can be saved as a raster file (GeoTIFF)
#' to a designated directory.
#' 
#' There are a few things to note regarding the raster image that OTP creates:
#' \itemize{
#' \item The travel time cutoff for a surface is hard-coded within OTP at 120 minutes. Every grid
#'  cell within the extent of the graph that is 120 minutes travel time or beyond, or not accessible,
#'  is given the value of 120.
#' \item Any grid cell outside of the extent of the network (i.e. unreachable) is given the value 128.
#' \item It is advisable to interpret the raster of a surface in conjunction with results from 
#' evaluating the surface.
#' \item OTP can take a while the first time a raster of a surface is generated after starting up. Subsequent
#' rasters (even for different origins) are much faster to generate.
#' }
#' @param otpcon An OTP connection object produced by \code{\link{otp_connect}}.
#' @param getRaster Logical. Whether or not to download a raster (geoTIFF) of the generated
#' surface. Default FALSE.
#' @param rasterPath Character. Path of a directory where the the surface raster
#' should be saved if \code{getRaster} is TRUE. Default is \code{tempdir()}. Use forward slashes on Windows.
#' The file will be named surface_{id}.tiff, with {id} replaced by the OTP id assigned
#' to the surface.
#' @param fromPlace Numeric vector, Latitude/Longitude pair, e.g. `c(53.48805, -2.24258)`. This is
#' the origin of the surface to be created.
#' @param mode Character vector, mode(s) of travel. Valid values are: WALK, BICYCLE,
#' CAR, TRANSIT, BUS, RAIL, TRAM, SUBWAY OR 'c("TRANSIT", "BICYCLE")'. TRANSIT will use all
#' available transit modes. Default is CAR. WALK mode is automatically
#' added for TRANSIT, BUS, RAIL, TRAM, and SUBWAY.
#' @param date Character, must be in the format mm-dd-yyyy. This is the desired date of travel.
#' Only relevant for transit modes. Default is the current system date.
#' @param time Character, must be in the format hh:mm:ss.
#' If \code{arriveBy} is FALSE (the default) this is the desired departure time, otherwise the
#' desired arrival time. Only relevant for transit modes. Default is the current system time.
#' @param arriveBy Logical. Whether a trip should depart (FALSE) or arrive (TRUE) at the specified
#' date and time. Default is FALSE.
#' @param maxWalkDistance Numeric. The maximum distance (in meters) that the user is
#' willing to walk. Default is NULL (the parameter is not passed to the API and the OTP
#' default of unlimited takes effect).
#' This is a soft limit in OTPv1 and is ignored if the mode is WALK only. In OTPv2
#' this parameter imposes a hard limit on WALK, CAR and BICYCLE modes (see:
#' \url{http://docs.opentripplanner.org/en/latest/OTP2-MigrationGuide/#router-config}).
#' @param walkReluctance A single numeric value. A multiplier for how bad walking is
#' compared to being in transit for equal lengths of time. Default = 2.
#' @param waitReluctance A single numeric value. A multiplier for how bad waiting for a
#' transit vehicle is compared to being on a transit vehicle. This should be greater
#' than 1 and less than \code{walkReluctance} (see API docs). Default = 1.
#' @param transferPenalty Integer. An additional penalty added to boardings after
#' the first. The value is in OTP's internal weight units, which are roughly equivalent to seconds.
#' Set this to a high value to discourage transfers. Default is 0.
#' @param minTransferTime Integer. The minimum time, in seconds, between successive
#' trips on different vehicles. This is designed to allow for imperfect schedule
#' adherence. This is a minimum; transfers over longer distances might use a longer time.
#' Default is 0.
#' @param batch Logical. Set to TRUE by default. This is required to tell OTP
#' to allow a query without the  \code{toPlace} parameter. This is necessary as we want to build
#' paths to all destinations from one origin.
#' @param extra.params A list of any other parameters accepted by the OTP API SurfaceResource entry point. For
#' advanced users. Be aware that otpr will carry out no validation of these additional
#' parameters. They will be passed directly to the API.
#' @return Assuming no error, returns a list of 5 elements:
#' \itemize{
#' \item \code{errorId} Will be "OK" if no error condition.
#' \item \code{surfaceId} The id of the surface that was evaluated.
#' \item \code{surfaceRecord} Details of the parameters used to create the surface.
#' \item \code{rasterDownload} The path to the saved raster file (if \code{getRaster} was
#' set to TRUE and a valid path was provided via \code{rasterPath}.)
#' \item \code{query} The URL that was submitted to the OTP API.
#' }
#' If there is an error, a list containing 3 elements is returned:
#' \itemize{
#' \item \code{errorId} The id code of the error.
#' \item \code{errorMessage} The error message.
#' \item \code{query} The URL that was submitted to the OTP API.
#' }
#' @examples \dontrun{
#' otp_create_surface(otpcon, fromPlace = c(53.43329,-2.13357), mode = "TRANSIT",
#' maxWalkDistance = 1600, getRaster = TRUE)
#'
#' otp_create_surface(otpcon, fromPlace = c(53.43329,-2.13357), date = "03-26-2019",
#' time = "08:00:00", mode = "BUS", maxWalkDistance = 1600, getRaster = TRUE,
#' rasterPath = "C:/temp")
#'}
#' @export
otp_create_surface <-
  function(otpcon,
           getRaster = FALSE,
           rasterPath = tempdir(),
           fromPlace,
           mode = "TRANSIT",
           date = format(Sys.Date(), "%m-%d-%Y"),
           time = format(Sys.time(), "%H:%M:%S"),
           maxWalkDistance = NULL,
           walkReluctance = 2,
           waitReluctance = 1,
           transferPenalty = 0,
           minTransferTime = 0,
           batch = TRUE,
           arriveBy = TRUE,
           extra.params = list())
  {
    call <- sys.call()
    call[[1]] <- as.name('list')
    params <- eval.parent(call)
    params <-
      params[names(params) %in% c("getRaster", "rasterPath", "extra.params") == FALSE]
    
    if (otpcon$version != 1) {
      stop(
        "OTP server is running OTPv",
        otpcon$version,
        ". otp_create_surface() is only supported in OTPv1"
      )
    }
    
    # Check for required arguments
    if (missing(otpcon)) {
      stop("otpcon argument is required")
    } else if (missing(fromPlace)) {
      stop("fromPlace argument is required")
    }
    
    # /otp/surface API endpoint must be enabled on the OTP instance (requires --analyst on launch)
    req <-
      try(httr::GET(paste0(make_url(otpcon)$otp, "/surfaces")), silent = T)
    if (class(req) == "try-error") {
      stop("Unable to connect to OTP. Does ",
           make_url(otpcon)$otp,
           " even exist?")
    } else if (req$status_code != 200) {
      stop(
        "Unable to connect to surface API. Was ",
        make_url(otpcon)$otp,
        " launched in analyst mode using --analyst ?"
      )
    }
    
    
    # function specific argument checks
    
    args.coll <- checkmate::makeAssertCollection()
    checkmate::assert_list(extra.params)
    checkmate::assert_logical(getRaster, add = args.coll)
    checkmate::assert_character(rasterPath, add = args.coll)
    checkmate::assert_path_for_output(
      file.path(rasterPath, paste0("test.tiff"), fsep = .Platform$file.sep),
      overwrite = TRUE,
      add = args.coll
    )
    checkmate::reportAssertions(args.coll)
    
    # check and process mode (adds WALK where required)
    mode <- otp_check_mode(mode)
    
    # OTP API parameter checks
    do.call(otp_check_params, params)
    
    # Construct URL
    surfaceUrl <- paste0(make_url(otpcon)$otp, "/surfaces")
    
    # Construct query list
    query <- list (
      fromPlace = paste(fromPlace, collapse = ","),
      mode = mode,
      date = date,
      time = time,
      maxWalkDistance = maxWalkDistance,
      walkReluctance = walkReluctance,
      waitReluctance = waitReluctance,
      transferPenalty = transferPenalty,
      minTransferTime = minTransferTime,
      arriveBy = FALSE,
      batch = TRUE
    )
    
    # append extra.params to query if present
    if (length(extra.params) > 0) {
      msg <- paste("Unknown parameters were passed to the OTP API without checks:", paste(sapply(names(extra.params), paste), collapse=", "))
      warning(paste(msg), call. = FALSE)
      query <- append(query, extra.params)
    }
    
    req <- httr::POST(surfaceUrl,
                      query = query)
    
    # decode URL for return
    url <- urltools::url_decode(req$url)
    
    # convert response content into text
    text <- httr::content(req, as = "text", encoding = "UTF-8")
    
    # Check that a surface is returned
    if (grepl("\"id\":", text)) {
      errorId <- "OK"
      surfaceId <-
        as.numeric(regmatches(text, regexec('id\":(.{1,3}),', text))[[1]][2])
      surfaceRecord <- text
      if (getRaster == TRUE) {
        download_path <-
          file.path(rasterPath,
                    paste0("surface_", surfaceId, ".tiff"),
                    fsep = .Platform$file.sep)
        check <-
          try(httr::GET(
            paste0(surfaceUrl, "/", surfaceId, "/raster"),
            httr::write_disk(download_path, overwrite = TRUE)
          ), silent = T)
        if (class(check) == "try-error") {
          rasterDownload <- check[1]
        } else{
          rasterDownload <- check$request$output$path
        }
      } else {
        rasterDownload <- "Not requested"
      }
    } else {
      response <-
        list(
          "errorId" = "ERROR",
          "errorMessage" = "A surface was not successfully created",
          "query" = url
        )
      return (response)
    }
    
    response <-
      list(
        "errorId" = errorId,
        "surfaceId" = surfaceId,
        "surfaceRecord" = surfaceRecord,
        "rasterDownload" = rasterDownload,
        "query" = url
      )
    return (response)
    
  }
