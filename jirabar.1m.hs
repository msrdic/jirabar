#!/usr/bin/env /usr/local/bin/stack
{- stack
  --resolver lts-18.4
  --install-ghc
  runghc
  --package wreq
  --package aeson
  --package lens-aeson
-}

-- <bitbar.title>Jira issues watcher</bitbar.title>
-- <bitbar.version>v0.1</bitbar.version>
-- <bitbar.author>Mladen Srdić</bitbar.author>
-- <bitbar.author.github>msrdic</bitbar.author.github>
-- <bitbar.desc>
--   This plugin does two things:
--     1/ it fetches Jira issues for a desired criteria and shows them,
--        both in menubar and dropdown
--     2/ it adds you to a list of watchers for those issues
--   Watching issues and both kinds of displays are optional.
-- </bitbar.desc>
-- <bitbar.dependencies>haskell, stack</bitbar.dependencies>

{-# LANGUAGE OverloadedStrings #-}

import           Control.Lens
import           Data.Aeson         (toJSON)
import           Data.Aeson.Lens
import           Data.Maybe         (fromMaybe)
import qualified Data.Text          as DT
import           Data.Text.Encoding (decodeUtf8)
import qualified Data.Vector        as DV
import           Network.Wreq

-- your Jira credentials
jiraAPIPath = "[YOUR JIRA API PATH]"
username = "[YOUR JIRA USERNAME]"
password = "[YOUR JIRA PASSWORD]"
credentials = basicAuth username password

-- your Jira browse path
-- this is usually of the form https://<address-to-your-jira>/browse
-- the 'browse' path segment is important since it is used for
-- generating clickable links in the dropdown
jiraBrowsePath = "[YOUR JIRA ADDRESS]"

-- IMPORTANT: whenever you're referring to your username in queries below,
-- use the supplied username' value.
username' = decodeUtf8 username

-- this is where you add a new section; just add a comma and a new line with the
-- required parameters set to what you need.
sectionDescriptors =
  -- this example query will list all bugs that were open after the start of the
  -- current day. It will fetch at most 50 issues, it will add you to a list of
  -- issue watchers (only if you're not already watching it). Additionally, it
  -- will appear in your menubar (ShowInMenubar), but only if more than 0 such
  -- issues exist (HideEmpty) and will render a section with all of the issues
  -- in a dropdown list.
  [ newSectionDescriptor "🐞" "Today's bugs" "issuetype = Bug AND created > startOfDay()" Watch 50 ShowInMenubar HideEmpty ShowIssueList ]

-- implementation details are below
-- everything needed for using this plugin is above

data DisplayInMenubar = ShowInMenubar | HideInMenubar deriving (Show, Eq)
data DisplayIssueList = ShowIssueList | HideIssueList deriving (Show, Eq)
data DisplayEmpty     = ShowEmpty | HideEmpty deriving (Show, Eq)
data WatchIssue       = Watch | NoWatch deriving (Show, Eq)

data SectionDescriptor =
     SectionDescriptor { icon       :: DT.Text
                       , title      :: DT.Text
                       , jql        :: DT.Text
                       , watch      :: WatchIssue
                       , maxIssues  :: Integer
                       , displayMB  :: DisplayInMenubar
                       , displayIf0 :: DisplayEmpty
                       , displayII  :: DisplayIssueList
                       }

-- just aliases for readability
type Key     = DT.Text
type Summary = DT.Text
type Watched = Bool

-- SectionResults contain a list of issues from Jira, but also
-- contain some information propagated from SectionDescriptor.
-- SectionResults instances are processed for displaying, so
-- we just copy that needed info here instead of mapping
-- results to descriptors. Just easier this way (:
data SectionResults =
     SectionResults { issues      :: [(Key, Summary, Watched)]
                    , icon'       :: DT.Text
                    , watch'      :: WatchIssue
                    , title'      :: DT.Text
                    , total       :: Integer
                    , displayMB'  :: DisplayInMenubar
                    , displayIf0' :: DisplayEmpty
                    , displayII'  :: DisplayIssueList
                    }

newSectionDescriptor icon title jql watch maxIssues display displayIf0 displayII =
  SectionDescriptor { icon = icon
                    , title = title
                    , jql = jql
                    , watch = watch
                    , maxIssues = maxIssues
                    , displayMB = display
                    , displayIf0 = displayIf0
                    , displayII = displayII
                    }

main = do
  sections <- mapM processSection sectionDescriptors
  let mainInfo = mainInfo' sections
  putStrLn $ DT.unpack mainInfo
  putStrLn "---"
  mapM_ printSection $ filter (\sr -> displayII' sr == ShowIssueList) sections

-- JSON extractors
extractIssues j = j ^. responseBody ^. key "issues" . _Array
extractTotal j = j ^. responseBody ^? key "total" . _Integer
extractIssueKey j = j ^. key "key" . _String
extractSummaryFromIssue j = j ^. key "fields" . key "summary" . _String
extractWatchesFromIssue j = j ^? key "fields" . key "watches" . key "isWatching" . _Bool

-- Process SectionDescriptors into SectionResults
processSection :: SectionDescriptor -> IO SectionResults
processSection sd = do
  issuesResponse <- getIssues (jql sd) (maxIssues sd)
  let issues    = extractIssues issuesResponse
      total'    = fromMaybe 0 $ extractTotal issuesResponse
      keys      = DV.toList $ DV.map extractIssueKey issues
      summaries = DV.toList $ DV.map extractSummaryFromIssue issues
      watches   = DV.toList $ DV.map (fromMaybe False) $ DV.map extractWatchesFromIssue issues
  return SectionResults { icon' = icon sd
                        , issues = zip3 keys summaries watches
                        , watch' = watch sd
                        , title' = title sd
                        , total = total'
                        , displayMB' = displayMB sd
                        , displayIf0' = displayIf0 sd
                        , displayII' = displayII sd
                        }

-- Construct the main menu bar item, one which will be visible
mainInfo' :: [SectionResults] -> DT.Text
mainInfo' = DT.intercalate "\x00A0" . filter (not . DT.null) . map sectionInfo

sectionInfo :: SectionResults -> DT.Text
sectionInfo section | noIssues && display0 && display = DT.concat [icon, DT.pack total']
                    | noIssues && dontDisplay0 = ""
                    | hasIssues && display = DT.concat [icon, DT.pack total']
                    | otherwise = ""
                    where noIssues     = null $ issues section
                          hasIssues    = not noIssues
                          display0     = displayIf0' section == ShowEmpty
                          dontDisplay0 = displayIf0' section == HideEmpty
                          display      = displayMB' section == ShowInMenubar
                          icon         = icon' section
                          total'       = show $ total section

printSection :: SectionResults -> IO ()
printSection sr = do
  putStrLn $ sectionTitle sr
  case watch' sr of Watch -> mapM_ (watchAndPrintIssue $ icon' sr) $ issues sr
                    NoWatch -> mapM_ (printIssue $ icon' sr) $ issues sr
  putStrLn "---"

sectionTitle sr =
  DT.unpack $ DT.concat [ ic, ti, " (", cnt, "/", tot, ")", "|color=gray"]
                        where ic = icon' sr
                              ti = title' sr
                              cnt = DT.pack $ show $ length $ issues sr
                              tot = DT.pack $ show $ total sr

watchAndPrintIssue icon p@(key, _, watched) =
  if not watched then
    do
      response <- watchIssue key
      if response ^. responseStatus ^. statusCode == 204
        then printIssue "╰✔︎" p
        else printIssue "╰✘" p
    else printIssue icon p

printIssue icon p = putStrLn $ DT.unpack (issue icon p)
issue icon (key, summary, _) = DT.concat [icon, key, ": " , summary, "|", "href=", jiraBrowsePath, key ]

-- add myself to a list of watchers
watchIssue key = do
  let params = defaults & auth ?~ credentials
  postWith params (jiraAPIPath ++ "issue/" ++ DT.unpack key ++ "/watchers") (toJSON username')

getIssues jql maxIssues = do
    let params = defaults & param "jql" .~ [jql]
                          & param "fields" .~ ["key,summary,watches"]
                          & param "maxResults" .~ [DT.pack $ show maxIssues]
                          & auth ?~ credentials
    getWith params $ jiraAPIPath ++ "search"
