# TMF Upgrade Plan: Craft 5 + Vite + contentBuilder

## Overview

This document outlines a phased approach to upgrading TMF from Craft 4 to Craft 5, refactoring templates, migrating from Laravel Mix to Vite, and implementing a new contentBuilder Matrix field.

**Total Phases: 5** (with testing checkpoints between each)

### Commit Strategy
- **Commit often** with atomic, focused commits
- Each commit should be independently revertable
- Use descriptive commit messages referencing phase/step
- Run `ddev craft db/backup` before field config changes

### Testing Environment
- All work performed locally on DDEV
- Push to staging environment when complete
- Production deployment after staging validation

---

## Phase 1: Core Craft 5 Upgrade

### Goal
Upgrade to Craft 5 with minimal field changes. Keep `sebastianlenz/linkfield` temporarily.

### Plugin Changes (Phase 1 Only)

| Plugin | Action | Notes |
|--------|--------|-------|
| `craftcms/cms` | Upgrade | 4.17.12 → 5.x |
| `craftcms/redactor` | Replace | → `craftcms/ckeditor` |
| `sebastianlenz/linkfield` | **KEEP** | Migrate in Phase 3 |
| `dolphiq/redirect` | Remove | No longer needed |
| `hybridinteractive/craft-position-fieldtype` | Remove | Replace with Dropdown |
| `verbb/redactor-tweaks` | Remove | Not needed with CKEditor |
| `spicyweb/craft-neo` | Upgrade | 4.x → 5.x |
| `nystudio107/craft-seomatic` | Upgrade | 4.x → 5.x |
| `verbb/formie` | Upgrade | 2.x → 3.x |
| `verbb/super-table` | Upgrade | 3.x → 4.x |
| `verbb/field-manager` | Upgrade | 3.x → 4.x |
| `verbb/tablemaker` | Upgrade | 4.x → 5.x |
| `craftcms/feed-me` | Upgrade | 5.x → 6.x |
| `craftcms/mailgun` | Upgrade | 3.x → 4.x |
| `spicyweb/craft-embedded-assets` | Upgrade | 4.x → 5.x |
| `mmikkel/cp-field-inspect` | Upgrade | Check Craft 5 version |
| `miranj/craft-obfuscator` | Upgrade | Check Craft 5 version |
| `statikbe/craft-config-values` | Upgrade | Check Craft 5 version |
| `topshelfcraft/wordsmith` | Upgrade | 4.x → 5.x |

### Steps

1. **Backup**
   ```bash
   ddev craft db/backup
   ```

2. **Create upgrade branch**
   ```bash
   git checkout -b upgrade/craft-5
   ```

3. **Update composer.json**
   - Update `craftcms/cms` to `^5.0`
   - Update all compatible plugins to Craft 5 versions
   - Remove: `dolphiq/redirect`, `hybridinteractive/craft-position-fieldtype`, `verbb/redactor-tweaks`
   - Add: `craftcms/ckeditor`
   - **Keep**: `sebastianlenz/linkfield` (still works with Craft 5)

4. **Run Composer update**
   ```bash
   ddev composer update
   ```

5. **Run migrations**
   ```bash
   ddev craft migrate/all
   ddev craft project-config/apply
   ```

6. **Field migrations (Phase 1)**
   - Migrate Redactor fields → CKEditor (built-in migration)
   - Replace Position fields → Dropdown fields (manual)
   - **DO NOT touch linkfield yet**

7. **Template updates**
   - Update deprecated Twig syntax
   - Update Redactor field references if needed

8. **Commit**
   ```bash
   git add -A && git commit -m "Phase 1: Craft 5 upgrade complete"
   ```

### Testing Checklist
- [ ] All sections load without errors
- [ ] Forms submit correctly (Formie)
- [ ] SEO meta renders (SEOmatic)
- [ ] Neo blocks render correctly
- [ ] **Link fields still work** (using old plugin)
- [ ] Asset transforms work
- [ ] Control panel functions normally
- [ ] No critical deprecation warnings

### Phase 1 Complete
**STOP** → User tests and approves before Phase 2

---

## Phase 2: Template Refactoring

### Goal
Refactor templates to follow composition-dev patterns, leveraging Craft's `.render()` method and `_partials/entry/` structure. This prepares the codebase for the contentBuilder implementation.

### Pattern Overview

**composition-dev template architecture:**
```
templates/
├── _layout/           # Base layouts
├── _matrix/           # Matrix field renderers (pageBuilder, contentBuilder)
├── _partials/
│   ├── entry/         # Entry type templates (called via .render())
│   └── block/         # Content Block field templates
├── _components/       # Reusable Twig partials
└── _sections/         # Section routing templates
```

**The `.render()` pattern:**
```twig
{# In _matrix/contentBuilder.twig #}
{% for block in entry.contentBuilder.all() %}
  {{ block.render({
    sectionId: sectionId,
    sectionSettings: sectionSettings
  }) }}
{% endfor %}
```

This automatically looks for `_partials/entry/{entryTypeHandle}.twig`.

### Steps

1. **Backup**
   ```bash
   ddev craft db/backup
   ```

2. **Create template directory structure**
   ```
   templates/
   ├── _partials/
   │   └── entry/        # New - for .render() delegation
   ├── _matrix/          # New - for Matrix field loops
   └── _components/      # Existing or create
   ```

3. **Audit existing Neo templates**
   - Document all `_neoBlockTypes/` templates
   - Identify patterns that can be consolidated
   - Note any shared logic

4. **Create entry type partials**
   - Create `_partials/entry/` templates for existing entry types
   - Follow composition-dev naming convention (camelCase handles)

5. **Update section templates**
   - Refactor to use `.render()` where appropriate
   - Centralize section wrapper logic

6. **Commit incrementally**
   ```bash
   git add templates/_partials/entry/
   git commit -m "Phase 2: Add entry type partials for .render() pattern"
   ```

### Files to Create/Modify

**New directories:**
- `templates/_partials/entry/` (entry type templates)
- `templates/_matrix/` (matrix field renderers)

**Template pattern example:**
```twig
{# templates/_partials/entry/general.twig #}
{##
 # Entry Type: General
 # Template: _partials/entry/general.twig
 #
 # Variables available:
 #   - entry (the matrix block entry)
 #   - Any variables passed via .render()
 #}
<div class="entry-content">
  {# Entry type specific content #}
</div>
```

### Testing Checklist
- [ ] All existing pages render correctly
- [ ] Neo blocks still function
- [ ] No broken includes
- [ ] Section templates use consistent patterns

### Phase 2 Complete
**STOP** → User tests and approves before Phase 3

---

## Phase 3: Link Field Migration

### Goal
Migrate from `sebastianlenz/linkfield` to Craft 5's first-party Link field.

### Why Separate Phase?
- Data structure differs between plugin and native field
- Requires custom migration script
- Content stored in `lenz_linkfield` table must move to `elements_sites`
- Template syntax changes required
- [GitHub Discussion #15993](https://github.com/craftcms/cms/discussions/15993)
- [Plugin Issue #286](https://github.com/sebastian-lenz/craft-linkfield/issues/286)

### Migration Strategy

#### Option A: Manual Migration (Recommended)
1. Create new Link fields with handle `hyperlink` (or field-specific handles)
2. Add new fields to field layouts alongside old fields
3. Write migration script to copy data from old to new
4. Update templates to use new fields
5. Remove old fields after verification
6. Remove `sebastianlenz/linkfield` plugin

#### Option B: In-Place Migration (Riskier)
1. Use community migration script from [Issue #286](https://github.com/sebastian-lenz/craft-linkfield/issues/286)
2. Convert field types in database
3. Migrate content from `lenz_linkfield` table
4. Update templates

### Template Changes Required

**Before (sebastianlenz/linkfield):**
```twig
{% if entry.linkField.hasElement() %}
  <a href="{{ entry.linkField.getUrl() }}">{{ entry.linkField.getText() }}</a>
{% endif %}
```

**After (native Link field):**
```twig
{% if entry.hyperlink.value %}
  {{ tag('a', {
    href: entry.hyperlink.value,
    target: entry.hyperlink.target,
    text: entry.hyperlink.label ?? entry.hyperlink.value
  }) }}
{% endif %}
```

### Steps

1. **Backup**
   ```bash
   ddev craft db/backup
   ```

2. **Audit existing link fields**
   - List all fields using `typedlinkfield\fields\LinkField`
   - Document which entry types/sections use them

3. **Create new Link fields** (via CP or project config)

4. **Write/run migration script**

5. **Update templates**

6. **Test thoroughly**

7. **Remove old plugin**
   ```bash
   ddev composer remove sebastianlenz/linkfield
   ```

8. **Commit**
   ```bash
   git add -A && git commit -m "Phase 3: Link field migration complete"
   ```

### Testing Checklist
- [ ] All link fields display correctly on frontend
- [ ] All link fields editable in control panel
- [ ] Entry links resolve correctly
- [ ] Asset links resolve correctly
- [ ] External URLs work
- [ ] Email links work
- [ ] Custom text/labels preserved
- [ ] Target attributes preserved

### Phase 3 Complete
**STOP** → User tests and approves before Phase 4

---

## Phase 4: Vite Migration

### Goal
Replace Laravel Mix with Vite for faster builds and HMR. Update Bootstrap and add libraries from composition-dev.

### Current State
- Laravel Mix 6.x with Webpack
- Bootstrap 5.2.2
- jQuery 3.6.1
- AOS 2.3.4

### Target State
- Vite 7.x with `nystudio107/craft-vite`
- Bootstrap 5.3.3
- jQuery 3.6.1 (keep)
- Additional libraries

### New Libraries to Add
| Library | Version | Purpose |
|---------|---------|---------|
| `@accessible360/accessible-slick` | ^1.0.1 | Accessible carousel |
| `@lottiefiles/dotlottie-web` | ^0.67.0 | Lottie animations |
| `@vimeo/player` | ^2.30.3 | Vimeo video player API |
| `youtube-player` | ^5.6.0 | YouTube video player API |
| `bootstrap-icons` | ^1.13.1 | Icon library |

### Steps

1. **Install craft-vite plugin**
   ```bash
   ddev composer require nystudio107/craft-vite
   ```

2. **Create Vite config** (`src/vite.config.js`)

3. **Update package.json**
   - Remove Laravel Mix dependencies
   - Add Vite and plugins
   - Update scripts

4. **Create Vite plugin config** (`config/vite.php`)

5. **Update template head**
   - Replace Mix asset helpers with Vite tag

6. **Update SCSS**
   - Bootstrap 5.2.2 → 5.3.3
   - Check for breaking changes in variables

7. **Test build process**
   - `npm run dev` (HMR)
   - `npm run build` (production)

8. **Commit**
   ```bash
   git add -A && git commit -m "Phase 4: Vite migration complete"
   ```

### Testing Checklist
- [ ] Dev server runs with HMR
- [ ] Production build completes
- [ ] All styles render correctly
- [ ] JavaScript functions (jQuery, Bootstrap JS)
- [ ] AOS animations work
- [ ] No console errors

### Phase 4 Complete
**STOP** → User tests and approves before Phase 5

---

## Phase 5: contentBuilder Matrix Field + NASAA + Globals

### Goal
Create a new contentBuilder Matrix field based on composition-dev patterns, import NASAA functionality from wesleyanimpactpartners, and set up globals.

### Part A: Import Base Fields from composition-dev

#### Base Utility Fields
| Handle | Type | Purpose |
|--------|------|---------|
| `plainText` | PlainText | Single-line text |
| `plainTextMonospace` | PlainText | Code-style single-line |
| `plainTextMultiline` | PlainText | Multi-line text |
| `plainTextMultilineMonospace` | PlainText | Code block |
| `yesNoYesDefault` | Lightswitch | Boolean (default: Yes) |
| `yesNoNoDefault` | Lightswitch | Boolean (default: No) |

#### Layout/Style Fields
| Handle | Type | Purpose |
|--------|------|---------|
| `textAlign` | Dropdown | start/center/end |
| `textColor` | Dropdown | Text color classes |
| `textSize` | Dropdown | Font size classes |
| `backgroundColor` | Dropdown | Background colors |
| `themeColor` | Dropdown | Theme accent colors |
| `sectionWidth` | Dropdown | Container/full-width |
| `sectionSpacing` | Dropdown | Vertical padding |
| `bootstrapContainer` | Dropdown | Container breakpoints |
| `breakpoint` | Dropdown | Responsive breakpoints |
| `aspectRatio` | Dropdown | Image/video ratios |
| `objectFit` | Dropdown | contain/cover/none |
| `imageAlignment` | Dropdown | float/full-width |
| `stackDirection` | Dropdown | vstack/hstack |
| `alignStartCenterEnd` | Dropdown | Flex align |
| `verticalStackAlignment` | Dropdown | Flex vertical align |
| `justifyPositional` | Dropdown | Flex justify |
| `scale` | Dropdown | Scale options |

#### Component Fields
| Handle | Type | Purpose |
|--------|------|---------|
| `hyperlink` | Link | First-party link (from Phase 3) |
| `hyperlinks` | Matrix | Multiple links |
| `button` | Matrix | Single button |
| `buttonGroup` | Matrix | Multiple buttons |
| `buttonStyle` | Dropdown | btn-primary, btn-outline, etc. |
| `buttonType` | Dropdown | link/modal |
| `headingAttributes` | Table | Heading level/style |
| `headingGroup` | Matrix | Heading + subheading |
| `sectionSettings` | Matrix | Block-level layout settings |
| `columnGroup` | Matrix | Column container |
| `columnBuilder` | Matrix | Column content builder |
| `richTextDefault` | CKEditor | Rich text |
| `image` | Assets | Image field |
| `url` | URL | URL field |

### Part B: Create Entry Types

| Handle | Icon | Fields |
|--------|------|--------|
| `headingBlock` | h2 | headingGroup, buttonGroup, sectionSettings |
| `textBlock` | paragraph | headingGroup, richTextDefault, buttonGroup, sectionSettings |
| `columnsBlock` | columns-3 | columnGroup, sectionSettings |
| `column` | columns-3 | textSize, textColor, textAlign, columnBuilder |
| `videoBlock` | circle-play | image (poster), url (video), sectionSettings |
| `imageBlock` | image-landscape | image, image (mobile), breakpoint, sectionWidth, sectionSettings |
| `embedCodeBlock` | rectangle-code | plainTextMultilineMonospace, sectionSettings |

### Part C: Create contentBuilder Matrix Field

```yaml
name: Content Builder
handle: contentBuilder
type: craft\fields\Matrix
settings:
  createButtonLabel: 'Add content block'
  entryTypes:
    - headingBlock (group: Content)
    - textBlock (group: Content)
    - columnsBlock (group: Layout)
    - videoBlock (group: Media)
    - imageBlock (group: Media)
    - embedCodeBlock (group: Utility)
```

### Part D: Import NASAA from wesleyanimpactpartners

**NASAA Filesystem:**
```yaml
nasaa:
  hasUrls: true
  name: NASAA
  settings:
    bucket: $DO_SPACES_BUCKET
    subfolder: nasaa
  type: vaersaagod\dospaces\Fs
  url: $DO_SPACES_CDN
```

**NASAA Fields:**
- `NASAA: Download Releases` - Matrix field for downloadable releases
- `NASAA: Rate Table Releases` - Matrix field for rate table data
- `NASAA Download Selector` - Entry selector for downloads
- `NASAA Rate Table Release` - Entry type for rate tables

**NASAA Global Set:**
- Handle: `nasaa`
- Tabs: Downloads, Rate Tables
- Fields: Download releases, Rate table releases, Fixed term headers/footers

### Part E: Create Globals

Import/create globals following wesleyanimpactpartners pattern:
- `header` - Site header configuration
- `footer` - Site footer configuration
- `nasaa` - NASAA-specific settings

### Templates to Create

```
templates/
├── _partials/
│   └── entry/
│       ├── headingBlock.twig
│       ├── textBlock.twig
│       ├── columnsBlock.twig
│       ├── column.twig
│       ├── videoBlock.twig
│       ├── imageBlock.twig
│       └── embedCodeBlock.twig
├── _matrix/
│   └── contentBuilder.twig
└── _cp/
    ├── globals_nasaa_downloads.twig
    └── globals_nasaa_rate_tables.twig
```

### Implementation Steps

1. **Backup**
   ```bash
   ddev craft db/backup
   ```

2. **Import base fields from composition-dev**
   - Copy field definitions from project.yaml
   - Adjust UIDs to be unique for TMF
   - Commit: `git commit -m "Phase 5: Import base fields from composition-dev"`

3. **Create entry types**
   - Create each entry type with field layouts
   - Commit: `git commit -m "Phase 5: Create contentBuilder entry types"`

4. **Create contentBuilder Matrix field**
   - Reference entry types
   - Configure groupings
   - Commit: `git commit -m "Phase 5: Create contentBuilder Matrix field"`

5. **Build templates**
   - Create renderer partial for each entry type
   - Create main contentBuilder loop template
   - Commit: `git commit -m "Phase 5: Create contentBuilder templates"`

6. **Import NASAA structure**
   - Create NASAA filesystem
   - Import NASAA fields
   - Create NASAA global
   - Commit: `git commit -m "Phase 5: Import NASAA from wesleyanimpactpartners"`

7. **Create header/footer globals**
   - Commit: `git commit -m "Phase 5: Create header/footer globals"`

8. **Add contentBuilder to entry types**
   - Add to relevant section entry types
   - Commit: `git commit -m "Phase 5: Add contentBuilder to entry type layouts"`

9. **Test with sample content**

### Testing Checklist
- [ ] All block types render correctly
- [ ] Heading levels/styles work
- [ ] Rich text displays properly
- [ ] Buttons link correctly
- [ ] Columns responsive at all breakpoints
- [ ] Video embeds play (YouTube/Vimeo)
- [ ] Images display with proper sizing
- [ ] Embed code renders safely
- [ ] Section settings (spacing, width) work
- [ ] Nested content (columns > columnBuilder) works
- [ ] NASAA downloads functional
- [ ] NASAA rate tables display correctly
- [ ] Globals editable in CP

---

## Documentation Updates

Update `PROJECT_CONTEXT.md` after major structural changes:
- After Phase 1: Update Craft version, plugin list
- After Phase 2: Update template architecture section
- After Phase 3: Update link field notes
- After Phase 4: Update frontend stack section
- After Phase 5: Update content model, add contentBuilder details, NASAA section

---

## Risk Mitigation

1. **Database backup** before each phase and before field config changes
2. **Git branches** for each phase
3. **Atomic commits** for easy rollback
4. **Local testing** before staging deployment
5. **Neo content preserved** - existing content unaffected
6. **Rollback plan** - `git revert` to previous commit

---

## Summary

| Phase | Scope | Risk Level |
|-------|-------|------------|
| 1 | Core Craft 5 + CKEditor | Medium |
| 2 | Template Refactoring (.render() pattern) | Low |
| 3 | Link Field Migration | **High** |
| 4 | Vite + Bootstrap 5.3 | Low |
| 5 | contentBuilder + NASAA + Globals | Medium |

---

## Resources

- [Craft 5 Upgrade Guide](https://craftcms.com/docs/5.x/upgrade.html)
- [Link Field Migration Discussion](https://github.com/craftcms/cms/discussions/15993)
- [linkfield Plugin Issue #286](https://github.com/sebastian-lenz/craft-linkfield/issues/286)
- [Vite Plugin Docs](https://nystudio107.com/docs/vite/)
- [Bootstrap 5.3 Migration](https://getbootstrap.com/docs/5.3/migration/)
- [Craft Element `.render()` method](https://craftcms.com/docs/5.x/reference/element-types/entries.html#render)

---

## Section Migration Strategy

### Rename Existing Pages Section
1. Rename section `pages` → `pagesNeo`
2. Rename entry type `general` → `pagesNeoGeneral`
3. Rename entry type `impactReport` → `pagesNeoImpactReport`

### Create New Pages Section
1. Create new section `pages` (Structure)
2. Create entry type `pagesGeneral` with `contentBuilder` field

### Template Refactoring Scope
- **Focus**: New contentBuilder field and entry types
- **Plan for**: Migrating all first-party entry types to `.render()` pattern
- **Leave as-is**: Neo implementation (templates in `_neoBlockTypes/`)

---

## Asset Storage (DO Spaces)

Bucket: `tmf`
Folders: `database`, `documents`, `images`, `transforms`, `nasaa`, `videos`

### Filesystems to Configure
```yaml
images:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: images
documents:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: documents
nasaa:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: nasaa
videos:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: videos
transforms:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: transforms
```

---

## Globals Strategy

- **Keep**: All existing TMF globals
- **Add**: NASAA global (from wesleyanimpactpartners pattern)

---

## Operational Notes

- **Compact conversation** at ~90-95% context usage
- **Ask questions** for non-obvious situations not defined in CLAUDE.md files
- **Run `/init`** before starting each phase

---

## Next Steps

1. **Review and approve** this plan
2. **Sync production database** to local: `npm run sync-db`
3. **Run `/init`** to refresh context
4. **Begin Phase 1**: Craft 5 Upgrade
