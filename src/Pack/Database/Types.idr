module Pack.Database.Types

import Core.Name.Namespace
import Data.List1
import Data.List.Elem
import Data.SortedMap
import Data.String
import Idris.Package.Types
import Pack.Core.Ipkg
import Pack.Core.Types

%default total

--------------------------------------------------------------------------------
--          MetaCommits
--------------------------------------------------------------------------------

||| A git commit hash or tag, or a meta commit: The latest commit of a branch.
public export
data MetaCommit : Type where
  MC     : Commit -> MetaCommit
  Latest : Branch -> MetaCommit
  Fetch  : Branch -> MetaCommit

public export
FromString MetaCommit where
  fromString s = case forget $ split (':' ==) s of
    ["latest",branch]       => Latest $ MkBranch branch
    ["fetch-latest",branch] => Fetch $ MkBranch branch
    _                       => MC $ MkCommit s

export
Interpolation MetaCommit where
  interpolate (Latest b) = "latest:\{b}"
  interpolate (Fetch b)  = "fetch-latest:\{b}"
  interpolate (MC c)     = "\{c}"

--------------------------------------------------------------------------------
--          Core Packages
--------------------------------------------------------------------------------

||| Core packages bundled with the Idris compiler
public export
data CorePkg =
    Prelude
  | Base
  | Contrib
  | Linear
  | Network
  | Test
  | IdrisApi

||| The list of core packages.
public export
corePkgs : List CorePkg
corePkgs = [Prelude, Base, Contrib, Linear, Network, Test, IdrisApi]

export
Interpolation CorePkg where
  interpolate Prelude  = "prelude"
  interpolate Base     = "base"
  interpolate Contrib  = "contrib"
  interpolate Linear   = "linear"
  interpolate Network  = "network"
  interpolate Test     = "test"
  interpolate IdrisApi = "idris2"

export
Cast CorePkg Body where
  cast Prelude  = "prelude"
  cast Base     = "base"
  cast Contrib  = "contrib"
  cast Linear   = "linear"
  cast Network  = "network"
  cast Test     = "test"
  cast IdrisApi = "idris2"

export %inline
Cast CorePkg (Path Rel) where
  cast c = PRel [< cast c]

||| Package name of a core package.
export
corePkgName : CorePkg -> PkgName
corePkgName = MkPkgName . interpolate

||| `.ipkg` file name corrsponding to a core package.
export
coreIpkgFile : CorePkg -> Body
coreIpkgFile IdrisApi = "idris2api.ipkg"
coreIpkgFile c        = cast c <+> ".ipkg"

||| Relative path to the `.ipkg` file corrsponding to a core package
||| (in the Idris2 project).
export
coreIpkgPath : CorePkg -> File Rel
coreIpkgPath IdrisApi = MkF neutral "idris2api.ipkg"
coreIpkgPath c        = MkF (neutral /> "libs" //> c) (coreIpkgFile c)

||| Try to convert a string to a core package.
export
readCorePkg : String -> Maybe CorePkg
readCorePkg "prelude" = Just Prelude
readCorePkg "base"    = Just Base
readCorePkg "contrib" = Just Contrib
readCorePkg "linear"  = Just Linear
readCorePkg "network" = Just Network
readCorePkg "test"    = Just Test
readCorePkg "idris2"  = Just IdrisApi
readCorePkg _         = Nothing

||| True, if the given string corresponds to one of the core packges.
export
isCorePkg : String -> Bool
isCorePkg = isJust . readCorePkg

--------------------------------------------------------------------------------
--          Packages
--------------------------------------------------------------------------------

||| Description of a GitHub or local Idris package in the
||| package database.
|||
||| Note: This does not contain the package name, as it
||| will be paired with its name in a `SortedMap`.
public export
data Package_ : (c : Type) -> Type where
  ||| A repository on GitHub, given as the package's URL,
  ||| commit (hash or tag), and name of `.ipkg` file to use.
  ||| `pkgPath` should be set to `True` for executables which need
  ||| access to the `IDRIS2_PACKAGE_PATH`: The list of directories
  ||| where Idris packages are installed.
  GitHub :  (url     : URL)
         -> (commit  : c)
         -> (ipkg    : File Rel)
         -> (pkgPath : Bool)
         -> Package_ c

  ||| A local Idris project given as an absolute path to a local
  ||| directory, and `.ipkg` file to use.
  ||| `pkgPath` should be set to `True` for executable which need
  ||| access to the `IDRIS2_PACKAGE_PATH`: The list of directories
  ||| where Idris packages are installed.
  Local  :  (dir     : Path Abs)
         -> (ipkg    : File Rel)
         -> (pkgPath : Bool)
         -> Package_ c

  ||| A core package of the Idris2 project
  Core   : (core : CorePkg) -> Package_ c

export
traverse : Applicative f => (URL -> a -> f b) -> Package_ a -> f (Package_ b)
traverse g (GitHub u c i p) = (\c' => GitHub u c' i p) <$> g u c
traverse _ (Local d i p)    = pure $ Local d i p
traverse _ (Core c)         = pure $ Core c

||| An alias for `Package_ Commit`: A package description with
||| meta commits already resolved.
public export
0 Package : Type
Package = Package_ Commit

||| An alias for `Package_ MetaCommit`: A package description where
||| the commit might still contain meta information.
public export
0 UserPackage : Type
UserPackage = Package_ MetaCommit

||| Proof that a package is a core package
public export
data IsCore : Package -> Type where
  ItIsCore : IsCore (Core c)

export
Uninhabited (IsCore $ Local {}) where
  uninhabited _ impossible

export
Uninhabited (IsCore $ GitHub {}) where
  uninhabited _ impossible

||| Decides, if the given package represents
||| one of the core packages (`base`, `prelude`, etc.)
export
isCore : (p : Package) -> Dec (IsCore p)
isCore (Core {})   = Yes ItIsCore
isCore (GitHub {}) = No absurd
isCore (Local {})  = No absurd

||| Proof that a package is a local package
public export
data IsLocal : Package -> Type where
  ItIsLocal : IsLocal (Local {})

export
Uninhabited (IsLocal $ Core {}) where
  uninhabited _ impossible

export
Uninhabited (IsLocal $ GitHub {}) where
  uninhabited _ impossible

||| Decides, if the given package represents
||| a local package.
export
isLocal : (p : Package) -> Dec (IsLocal p)
isLocal (Core {})   = No absurd
isLocal (GitHub {}) = No absurd
isLocal (Local {})  = Yes ItIsLocal

||| Proof that a package is a GitHub package
public export
data IsGitHub : Package -> Type where
  ItIsGitHub : IsGitHub (GitHub {})

export
Uninhabited (IsGitHub $ Core {}) where
  uninhabited _ impossible

export
Uninhabited (IsGitHub $ Local {}) where
  uninhabited _ impossible

||| Decides, if the given package represents
||| a package on GitHub.
export
isGitHub : (p : Package) -> Dec (IsGitHub p)
isGitHub (Core {})   = No absurd
isGitHub (GitHub {}) = Yes ItIsGitHub
isGitHub (Local {})  = No absurd

||| True, if the given application needs access to the
||| folders where Idris package are installed.
export
usePackagePath : Package_ c -> Bool
usePackagePath (GitHub _ _ _ pp) = pp
usePackagePath (Local _ _ pp)    = pp
usePackagePath (Core _)          = False

||| Absolute path to the `.ipkg` file of a package.
export
ipkg : (dir : Path Abs) -> Package -> File Abs
ipkg dir (GitHub _ _ i _) = toAbsFile dir i
ipkg dir (Local _ i _)    = toAbsFile dir i
ipkg dir (Core c)         = toAbsFile dir (coreIpkgPath c)

--------------------------------------------------------------------------------
--          Resolved Packages
--------------------------------------------------------------------------------

||| Installation status of an Idris package. Local packages can be
||| `Outdated`, if some of their source files contain changes newer
||| a timestamp created during package installation.
public export
data PkgStatus : Package -> Type where
  Missing   :  PkgStatus p
  Installed :  PkgStatus p
  Outdated  :  (0 isLocal : IsLocal p) => PkgStatus p

||| A resolved library, which was downloaded from GitHub
||| or looked up in the local file system. This comes with
||| a fully parsed `PkgDesc` (representing the `.ipkg` file).
public export
record ResolvedLib t where
  constructor RL
  pkg     : Package
  name    : PkgName
  desc    : Desc t
  status  : PkgStatus pkg
  deps    : List (DPair Package PkgStatus)

namespace ResolveLib
  ||| Extracts the package name from a resolved library.
  export %inline
  nameStr : ResolvedLib t -> String
  nameStr = value . name

  ||| Change the type-level tag of a resolved library.
  export %inline
  reTag : ResolvedLib s -> Desc t -> ResolvedLib t
  reTag rl d = {desc := d} rl

  ||| Extracts the dependencies of a resolved library.
  export
  dependencies : ResolvedLib t -> List PkgName
  dependencies rp = dependencies rp.desc

namespace AppStatus
  ||| Installation status of an Idris app. Local apps can be
  ||| `Outdated`, if some of their source files contain changes newer
  ||| a timestamp created during package installation.
  public export
  data AppStatus : Package -> Type where
    ||| The app has not been compiled and is therfore missing
    Missing      :  AppStatus p

    ||| The app has been built but is not on the `PATH`.
    Installed    :  AppStatus p

    ||| The app has been built and a wrapper script has been added
    ||| to `$PACK_DIR/bin`, so it should be on the `PATH`.
    BinInstalled :  AppStatus p

    ||| The local app has changes in its source files, which have
    ||| not yet been included in the installed version.
    Outdated     :  (0 isLocal : IsLocal p) => AppStatus p

||| A resolved application, which was downloaded from GitHub
||| or looked up in the local file system. This comes with
||| a fully parsed `PkgDesc` (representing the `.ipkg` file).
public export
record ResolvedApp t where
  constructor RA
  pkg     : Package
  name    : PkgName
  desc    : Desc t
  status  : AppStatus pkg
  exec    : Body
  deps    : List (DPair Package PkgStatus)

namespace ResolveApp
  ||| Extracts the package name from a resolved application.
  export %inline
  nameStr : ResolvedApp t -> String
  nameStr = value . name

  ||| Extracts the dependencies of a resolved application.
  export
  dependencies : ResolvedApp t -> List PkgName
  dependencies rp = dependencies rp.desc

  ||| Change the type-level tag of a resolved application.
  export %inline
  reTag : ResolvedApp s -> Desc t -> ResolvedApp t
  reTag rl d = {desc := d} rl

  ||| True, if the given application needs access to the
  ||| folders where Idris package are installed.
  export %inline
  usePackagePath : ResolvedApp t -> Bool
  usePackagePath = usePackagePath . pkg

||| Either a resolved library or application tagged with the given tag.
||| This is to be used in build plans, so applications come with the
||| additional info whether we want to install a wrapper script or not.
public export
data LibOrApp : (t,s : PkgDesc -> Type) -> Type where
  Lib : ResolvedLib t -> LibOrApp t s
  App : (withWrapperScript : Bool) -> ResolvedApp s -> LibOrApp t s

namespace LibOrApp
  ||| Extract the dependencies of a resolved library or application.
  export
  dependencies : LibOrApp t s -> List PkgName
  dependencies (Lib x)   = dependencies x
  dependencies (App _ x) = dependencies x

  ||| Extract the package of a resolved library or application.
  export
  pkg : LibOrApp t s -> Package
  pkg (Lib x)   = x.pkg
  pkg (App _ x) = x.pkg

  ||| Extract the description of a resolved library or application.
  export
  desc : LibOrApp t t -> Desc t
  desc (Lib x)   = x.desc
  desc (App _ x) = x.desc

  ||| Extract the package name of a resolved library or application.
  export
  name : LibOrApp t s -> PkgName
  name (Lib x)   = x.name
  name (App _ x) = x.name

--------------------------------------------------------------------------------
--          Package Database
--------------------------------------------------------------------------------

||| DB used for building packages. This includes
||| the Idris commit to use, together with a curated list of
||| known packages.
public export
record DB where
  constructor MkDB
  idrisURL     : URL
  idrisCommit  : Commit
  idrisVersion : PkgVersion
  packages     : SortedMap PkgName Package

tomlBool : Bool -> String
tomlBool True  = "true"
tomlBool False = "false"

printPair : (PkgName,Package) -> String
printPair (x, GitHub url commit ipkg pp) =
  """

  [db.\{x}]
  type        = "github"
  url         = "\{url}"
  commit      = "\{commit}"
  ipkg        = "\{ipkg}"
  packagePath = \{tomlBool pp}
  """

printPair (x, Local dir ipkg pp) =
  """

  [db.\{x}]
  type        = "local"
  path        = "\{dir}"
  ipkg        = "\{ipkg}"
  packagePath = \{tomlBool pp}
  """

printPair (x, Core c) =
  """

  [db.\{x}]
  type        = "core"
  """

||| Convert a package collection to a valid TOML string.
export
printDB : DB -> String
printDB (MkDB u c v db) =
  let header = """
        [idris2]
        url     = "\{u}"
        version = "\{v}"
        commit  = "\{c}"
        """
   in unlines $ header :: map printPair (SortedMap.toList db)

--------------------------------------------------------------------------------
--          Tests
--------------------------------------------------------------------------------

-- make sure no core package was forgotten
0 corePkgsTest : (c : CorePkg) -> Elem c Types.corePkgs
corePkgsTest Prelude  = %search
corePkgsTest Base     = %search
corePkgsTest Contrib  = %search
corePkgsTest Linear   = %search
corePkgsTest Network  = %search
corePkgsTest Test     = %search
corePkgsTest IdrisApi = %search

-- all core packages should be parsable from their
-- interpolation string
0 corePkgRoundTrip : (c : CorePkg) -> readCorePkg (interpolate c) === Just c
corePkgRoundTrip Prelude  = Refl
corePkgRoundTrip Base     = Refl
corePkgRoundTrip Contrib  = Refl
corePkgRoundTrip Linear   = Refl
corePkgRoundTrip Network  = Refl
corePkgRoundTrip Test     = Refl
corePkgRoundTrip IdrisApi = Refl
