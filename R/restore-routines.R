isTrustedPackage <- function(package) {
  untrusted <- getOption("packrat.untrusted.packages", default = character())
  !package %in% untrusted
}

hashTarball <- function(path) {
  # TODO: unpack, recursively hash, and combine? for now
  # we just hash the tarball as-is
  tools::md5sum(files = normalizePath(path, mustWork = TRUE))
}

restoreWithCopyFromCache <- function(project,
                                     pkgRecord,
                                     cacheCopyStatus)
{
  # don't copy from cache if disabled for this project
  if (!isUsingCache(project))
    return(FALSE)

  # don't try to use cache if we don't have a hash
  if (!length(pkgRecord$hash))
    return(FALSE)

  # don't try to cache uncacheable packages (ie, packages that
  # need to be reinstalled each time for whatever reason)
  if (!isCacheable(pkgRecord$name))
    return(FALSE)

  # ensure that the cache package path exists
  source <- cacheLibDir(pkgRecord$name, pkgRecord$hash, pkgRecord$name)
  if (!file.exists(source))
    return(FALSE)

  # attempt to form a symlink to the packrat library
  # (remove stale file if one exists)
  lib <- libDir(project)
  target <- file.path(lib, pkgRecord$name)
  if (file.exists(target)) {
    temp <- tempfile(tmpdir = lib)
    file.rename(target, temp)
    on.exit({
      if (file.exists(target))
        unlink(temp, recursive = !is.symlink(temp))
      else
        file.rename(temp, target)
    }, add = TRUE)
  }

  suppressWarnings(symlink(source, target))
  success <- file.exists(target)
  if (success) {
    cacheCopyStatus$type <- "symlinked cache"
    return(TRUE)
  }

  # symlinking failed; attempt a copy from the cache to the target directory
  success <- all(dir_copy(
    cacheLibDir(pkgRecord$name, pkgRecord$hash),
    file.path(libDir(project), pkgRecord$name)
  ))

  if (success) {
    cacheCopyStatus$type <- "copied cache"
    return(TRUE)
  }

  # failed to copy or symlink from cache; report warning and return false
  warning("failed to symlink or copy package '", pkgRecord$name, "' from cache")
  return(FALSE)
}

restoreWithCopyFromUntrustedCache <- function(project,
                                              pkgRecord,
                                              cacheCopyStatus)
{
  # don't copy from cache if disabled for this project
  if (!isUsingCache(project))
    return(FALSE)

  # don't try to cache uncacheable packages (ie, packages that
  # need to be reinstalled each time for whatever reason)
  if (!isCacheable(pkgRecord$name))
    return(FALSE)

  # attempt to find source tarball associated with passed-in
  # package record
  tarballName <- sprintf("%s_%s.tar.gz", pkgRecord$name, pkgRecord$version)
  tarballPath <- file.path(srcDir(project), pkgRecord$name, tarballName)
  if (!file.exists(tarballPath))
    return(FALSE)

  # attempt to hash tarball
  hash <- hashTarball(tarballPath)
  if (!is.character(hash))
    return(FALSE)

  # attempt to discover cached package in untrusted cache
  source <- untrustedCacheLibDir(pkgRecord$name, hash, pkgRecord$name)
  if (!file.exists(source))
    return(FALSE)

  # attempt to form a symlink to the packrat library
  # (remove stale file if one exists)
  lib <- libDir(project)
  target <- file.path(lib, pkgRecord$name)
  if (file.exists(target)) {
    temp <- tempfile(tmpdir = lib)
    file.rename(target, temp)
    on.exit({
      if (file.exists(target))
        unlink(temp, recursive = !is.symlink(temp))
      else
        file.rename(temp, target)
    }, add = TRUE)
  }

  suppressWarnings(symlink(source, target))
  success <- file.exists(target)
  if (success) {
    cacheCopyStatus$type <- "symlinked user cache"
    return(TRUE)
  }

  # symlinking failed; attempt a copy from the cache to the target directory
  success <- all(dir_copy(
    cacheLibDir(pkgRecord$name, pkgRecord$hash),
    file.path(libDir(project), pkgRecord$name)
  ))

  if (success) {
    cacheCopyStatus$type <- "copied user cache"
    return(TRUE)
  }

  # failed to copy or symlink from cache; report warning and return false
  warning("failed to symlink or copy package '", pkgRecord$name, "' from user cache")
  return(FALSE)
}
