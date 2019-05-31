#!/usr/bin/env Rscript

needed <- c("magrittr", "argparser", "httr", "glue", "rmarkdown")
installed <- rownames(installed.packages())
missing <- needed[!(needed %in% installed)]

if (length(missing)) stop("Please install the following packages: ", paste0(sprintf("'%s'", missing), collapse = ", "), call.=FALSE)

suppressPackageStartupMessages({
  for (pkg in needed) {
    require(package = pkg, quietly = TRUE, warn.conflicts = FALSE, character.only = TRUE)
  }
})

arg_parser(
  description = "Render 'The Art of the Command Line' to HTML"
) %>% 
  add_argument(
    arg = "--language",
    help = 'Language to render. Leave unspecified for English. Current known: "cs", "de", "el", "es", "fr", "id", "it", "ja", "ko", "pt", "ro", "ru", "sl", "uk", "zh-Hant", "zh"',
    type = "character",
    short = "-l",
    default = ""
  ) %>% 
  add_argument(
    arg = "--theme",
    help = "Which R Markdown document theme to use. Ref: https://l.rud.is/2JOibrZ",
    type = "character",
    short = "-t",
    default = "simplex"
  ) %>% 
  add_argument(
    arg = "--highlight",
    help = "Which R Markdown code higlight theme to use. Ref: https://l.rud.is/2JOibrZ",
    type = "character",
    short = "-c",
    default = "espresso"
  ) %>% 
  add_argument(
    arg = "--output-dir",
    help = "Where to store the rendered file. Defaults to current working directory.",
    type = "character",
    short = "-o",
    default = getwd()
  ) %>% 
  add_argument(
    arg = "--just-render",
    help = "Only render the document. Do not open in the system default browser. (Default is to render and open.)",
    short = "-j",
    flag = TRUE
  ) -> parser
  
opts <- argparser::parse_args(parser)

taotcl <- function(language = "", theme = "simplex", highlight = "espresso", output_dir = getwd(), open = TRUE) {
  
  language <- language[1]
  
  httr::GET(
    url = "https://api.github.com/repos/jlevy/the-art-of-command-line/contents/",
    httr::add_headers(
      `Accept` = "application/vnd.github.v3+json"
    ),
    httr::user_agent("taotcl R script; @hrbrmstr")
  ) -> res
  
  httr::stop_for_status(res)
  
  ls <- httr::content(res, as = "parsed")
  
  readmes <- Filter(function(.x) grepl("^README", .x), vapply(ls, `[[`, character(1), "name"))
  langs <- regmatches(readmes, regexpr("-[-[:alpha:]]+", readmes))
  
  if (language != "") { # "" => English
    language <- sprintf("-%s", language)
    if (!(language %in% langs)) {
      stop(
        "Language '", sub("^-", "", language), 
        "' not found in repo. Current translations include: ",
        paste0(sprintf("'%s'", sub("^-", "", langs)), collapse = ", "),
        ".", call.=FALSE
      )
    }
  }
  
  src <- "https://raw.githubusercontent.com/jlevy/the-art-of-command-line/master/README{language}.md"
  src <- glue::glue(src)
 
  l <- readLines(src)
  
  title <- sub("^#[[:space:]]*", "", l[which(grepl("^#[[:space:]]*", l))[1]])
  cowsay <- which(grepl("cowsay", l))[1]
  
  l <- l[-(1:(cowsay+1))]
  l <- gsub("(AUTHORS.md)", "(https://github.com/jlevy/the-art-of-command-line/blob/master/AUTHORS.md)", l, fixed = TRUE)
  
  theme <- theme[1]
  highlight <- highlight[1]
  
'---
title: "{title}"
author: "Joshua Levy"
email: "joshua@cal.berkeley.edu"
output: 
  html_document:
    theme: {theme}
    highlight: {highlight}
    toc: true
    toc_float: true
    toc_depth: 2
---

' -> yaml
  
  yaml <- glue::glue(yaml)
  
  tf <- tempfile(fileext = ".Rmd")
  on.exit(unlink(tf), add = TRUE)
  writeLines(c(yaml, l), tf)
  
  rmarkdown::render(
    input = tf,
    output_file = sprintf("%s.html", tolower(gsub(" ", "-", title))),
    output_dir = output_dir[1],
    quiet = TRUE
  ) -> loc
  
  if (open[1]) browseURL(loc)
  
  message("Rendered version is at '", loc, "'")
  
}

# Do the thing! ---------------------------------------------------------------------

taotcl(
  language = opts$language,
  theme = opts$theme,
  highlight = opts$highlight,
  output_dir = opts$output_dir,
  open = is.na(opts$just_render) | (!opts$just_render)
)
