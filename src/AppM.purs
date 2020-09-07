module AppM where

import Prelude

import Control.Monad.Reader.Trans   (class MonadAsk
                                    ,ReaderT
                                    ,ask, asks, runReaderT)
import Data.Argonaut                (encodeJson, decodeJson)
import Data.Either                  (Either(..))
import Data.Environment             (Environment(..), Env)
import Data.Maybe                   (Maybe(..))
import Data.String                  (drop)
import Effect.Aff                   (Aff)
import Effect.Aff.Class             (class MonadAff)
import Effect.Class                 (class MonadEffect
                                    ,liftEffect)
import Effect.Class.Console         (logShow)
import Effect.Console               as Console
import Elasticsearch.Client         (SearchResponse(..), SearchHit(..))
import Routing.Duplex               (print)
import Routing.Hash                 (setHash)
import Simple.JSON                  (write)
import Type.Equality                (class TypeEquals, from)
import Web.HTML                     (window)
import Web.HTML.Window              as Window
import Web.HTML.Location            (pathname, setHref, Location)
import Slug                         as Slug

import Api.Endpoint                 as API
import Api.Request                  (RequestMethod(..)
                                    ,FormDataRequestMethod(..)
                                    ,mkRequest
                                    ,mkFormDataRequest)
import Capability.LogMessages       (class LogMessages
                                    ,logMessage)
import Capability.Navigate          (class Navigate)
import Data.Auth                    (APIAuth(..)
                                    ,Password(..)
                                    ,apiAuth
                                    ,base64encodeUserAuth)
import Data.BlogPost                (BlogPost(..))
import Data.Image                   (decodeImageArray)
import Data.Log                     as Log
import Data.Route                   as Route
import Data.User                    (Username(..))
import Data.URL                     (BaseURL)
import Resource.BlogPost            (class ManageBlogPost)
import Resource.Media               (class ManageMedia)
import Resource.User                (class ManageUser)
import Resource.Tag                 (class ManageTag)


newtype AppM a = AppM (ReaderT Env Aff a)

runAppM :: Env -> AppM ~> Aff
runAppM env (AppM m) = runReaderT m env

derive newtype instance functorAppM :: Functor AppM
derive newtype instance applyAppM :: Apply AppM
derive newtype instance applicativeAppM :: Applicative AppM
derive newtype instance bindAppM :: Bind AppM
derive newtype instance monadAppM :: Monad AppM
derive newtype instance monadEffectAppM :: MonadEffect AppM
derive newtype instance monadAffAppM :: MonadAff AppM

instance monadAskAppM :: TypeEquals e Env => MonadAsk e AppM where
  ask = AppM $ asks from

instance logMessagesAppM :: LogMessages AppM where
  logMessage log = do 
    env <- ask
    liftEffect case env.environment of
      Production -> pure unit
      _ -> Console.log $ Log.message log

instance navigateAppM :: Navigate AppM where
  navigate route = do
    -- Get our PushStateInterface instance from env
    env <- ask
    let 
      href = "/" <> (print Route.routeCodec route)
    logShow href
    -- pushState new destination
    liftEffect $ 
      env.pushInterface.pushState 
      (write {}) 
      href

  -- TODO: remove
  navigateForm route = do
    w <- liftEffect window
    location <- liftEffect $ Window.location w
    let href = ("?#" <> (print Route.routeCodec route))
    liftEffect $ setHref href location

instance manageBlogPostAppM :: ManageBlogPost AppM where
  getBlogPosts pagination = do
    req <- mkRequest 
      { endpoint: API.BlogPosts pagination
      , method: Get
      , auth: Nothing
      }
    case req of
      Just json -> do
        let blogPosts = decodeJson json
        case blogPosts of
          Right bps -> pure bps
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure []
      Nothing -> pure []

  getBlogPost postId = do
    req <- mkRequest
      { endpoint: API.BlogPost postId
      , method: Get
      , auth: Nothing
      }
    case req of
      Just json -> do
        let blogPost = decodeJson json
        case blogPost of
          Right bps -> pure $ Just bps
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing

  getBlogPostBySlug slug = do
    req <- mkRequest
      { endpoint: API.BlogPostBySlug $ Slug.toString slug
      , method: Get
      , auth: Nothing
      }
    case req of
      Just json -> do
        let blogPost = decodeJson json
        case blogPost of
          Right bps -> pure $ Just bps
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing

  getBlogPostsByTagId tagId = do
    req <- mkRequest
      { endpoint: API.BlogPostsByTagId tagId
      , method: Get
      , auth: Nothing
      }
    case req of
      Just json -> do
        let blogPosts = decodeJson json
        case blogPosts of
          Right bps -> pure bps
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure []
      Nothing -> pure []
  
  searchBlogPost query = do
    req <- mkRequest
      { endpoint: API.BlogPostSearch
      , method: Post $ Just $ encodeJson query
      , auth: Nothing
      }
    case req of
      Just json -> do
        let 
          result = decodeJson json :: Either String (SearchResponse BlogPost)
        case result of
          Right (SearchResponse res) -> do
            let
              posts = map (\(SearchHit r) -> r.source) res.hits
            pure posts
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure []
      Nothing -> pure []

  createBlogPost post = do
    req <- mkRequest
      { endpoint: API.BlogPostCreate
      , method: Post $ Just $ encodeJson post
      , auth: Just apiAuth
      }
    case req of
      Just json -> do
        let blogPost = decodeJson json
        case blogPost of
          Right bps -> pure $ Just bps
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing

  updateBlogPost (BlogPost post) = do
    req <- mkRequest
      { endpoint: API.BlogPostUpdate post.id
      , method: Post $ Just $ encodeJson $ BlogPost post
      , auth: Just apiAuth
      }
    case req of
      Just json -> do
        let blogPost = decodeJson json
        case blogPost of
          Right bps -> pure $ Just bps
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing
  deleteBlogPost postId = do
    req <- mkRequest
      { endpoint: API.BlogPostDelete postId
      , method: Delete
      , auth: Just apiAuth
      }
    pure unit

instance manageMediaAppM :: ManageMedia AppM where
  getImages   pagination = do
    req <- mkRequest
      { endpoint: API.Images pagination
      , method: Get
      , auth: Nothing
      }
    case req of
      Just json -> do
        let images = decodeImageArray json
        case images of
          Right i -> pure i
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure []
      Nothing -> pure []

  deleteImage imageId = do
    req <- mkRequest
      { endpoint: API.ImageDelete imageId
      , method: Delete
      , auth: Just apiAuth
      }
    pure unit

  uploadImage formData = do
    req <- mkFormDataRequest
      { endpoint: API.ImageUpload
      , method: PostFormData $ Just formData
      , auth: Just apiAuth
      }
    case req of
      Just json -> do
        let img = decodeJson json
        case img of
          Right i -> pure $ Just i
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing

instance manageUserAppM :: ManageUser AppM where
  loginUser auth = do
    req <- mkRequest 
      { endpoint: API.UserLogin
      , method: Get
      , auth: Just $ Basic $ base64encodeUserAuth auth
      }
    case req of
      Just json -> do
        let user = decodeJson json
        case user of
          Right u -> pure $ Just u
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing

instance manageTagAppM :: ManageTag AppM where
  createTag tag = do
    req <- mkRequest
      { endpoint: API.TagCreate tag
      , method: Post Nothing
      , auth: Just apiAuth
      }
    case req of
      Just json -> do
        let newTag = decodeJson json
        case newTag of
          Right t -> pure $ Just t
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing

  getTagById tagId = do
    req <- mkRequest
      { endpoint: API.Tag tagId
      , method: Get
      , auth: Nothing
      }
    case req of
      Just json -> do
        let tag = decodeJson json
        case tag of
          Right t -> pure $ Just t
          Left err -> do
            logMessage $ Log.Log { message: err }
            pure Nothing
      Nothing -> pure Nothing
