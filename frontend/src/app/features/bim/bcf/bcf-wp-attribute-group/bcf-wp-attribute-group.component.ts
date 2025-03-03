import {
  AfterViewInit,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  Input,
  OnDestroy,
  OnInit,
  ViewChild,
} from '@angular/core';
import { StateService } from '@uirouter/core';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { NgxGalleryComponent, NgxGalleryOptions } from '@kolkov/ngx-gallery';
import { HalLink } from 'core-app/features/hal/hal-link/hal-link';
import idFromLink from 'core-app/features/hal/helpers/id-from-link';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { ViewerBridgeService } from 'core-app/features/bim/bcf/bcf-viewer-bridge/viewer-bridge.service';
import { UntilDestroyedMixin } from 'core-app/shared/helpers/angular/until-destroyed.mixin';
import { NotificationsService } from 'core-app/shared/components/notifications/notifications.service';
import { WorkPackageCreateService } from 'core-app/features/work-packages/components/wp-new/wp-create.service';
import { BcfAuthorizationService } from 'core-app/features/bim/bcf/api/bcf-authorization.service';
import { ViewpointsService } from 'core-app/features/bim/bcf/helper/viewpoints.service';
import { BcfViewpointItem } from 'core-app/features/bim/bcf/api/viewpoints/bcf-viewpoint-item.interface';
import { APIV3Service } from 'core-app/core/apiv3/api-v3.service';

@Component({
  templateUrl: './bcf-wp-attribute-group.component.html',
  styleUrls: ['./bcf-wp-attribute-group.component.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [ViewpointsService],
})
export class BcfWpAttributeGroupComponent extends UntilDestroyedMixin implements AfterViewInit, OnDestroy, OnInit {
  @Input() workPackage:WorkPackageResource;

  @ViewChild(NgxGalleryComponent) gallery:NgxGalleryComponent;

  text = {
    bcf: this.I18n.t('js.bcf.label_bcf'),
    viewpoint: this.I18n.t('js.bcf.viewpoint'),
    add_viewpoint: this.I18n.t('js.bcf.add_viewpoint'),
    show_viewpoint: this.I18n.t('js.bcf.show_viewpoint'),
    delete_viewpoint: this.I18n.t('js.bcf.delete_viewpoint'),
    text_are_you_sure: this.I18n.t('js.text_are_you_sure'),
    notice_successful_create: this.I18n.t('js.notice_successful_create'),
    notice_successful_delete: this.I18n.t('js.notice_successful_delete'),
  };

  galleryOptions:NgxGalleryOptions[] = [
    {
      width: '100%',
      height: '400px',

      // Show first thumbnail by default
      startIndex: 0,

      // Show only one image ("thumbnail")
      // and disable the large image slideshow
      image: false,
      thumbnailsColumns: 1,
      // Ensure thumbnails are ALWAYS shown
      thumbnailsAutoHide: false,
      // For BCFs all information shall be visible
      thumbnailSize: 'contain',
      imageAnimation: '',
      previewAnimation: false,
      previewCloseOnEsc: true,
      previewKeyboardNavigation: true,
      imageSize: 'contain',
      imageArrowsAutoHide: true,
      // thumbnailsArrowsAutoHide: true,
      thumbnailsMargin: 5,
      thumbnailMargin: 5,
      previewDownload: true,
      previewCloseOnClick: true,
      arrowPrevIcon: 'icon-arrow-left2',
      arrowNextIcon: 'icon-arrow-right2',
      closeIcon: 'icon-close',
      downloadIcon: 'icon-download',
      thumbnailActions: this.actions(),
      actions: this.actions(),
    },
    // max-width 800
    {
      breakpoint: 800,
      width: '100%',
      height: '400px',
      imagePercent: 80,
      thumbnailsPercent: 20,
      thumbnailsMargin: 5,
      thumbnailMargin: 5,
    },
    // max-width 680
    {
      breakpoint: 680,
      height: '200px',
      thumbnailsColumns: 3,
      thumbnailsMargin: 5,
      thumbnailMargin: 5,
    },
  ];

  viewpoints:BcfViewpointItem[] = [];

  galleryImages:any[] = [];

  // Store whether viewing is allowed
  viewAllowed = false;

  // Store whether viewpoint creation is allowed
  createAllowed = false;

  // Currently, this is static. Need observable if this changes over time
  viewerVisible = false;

  projectId:string;

  constructor(readonly state:StateService,
    readonly bcfAuthorization:BcfAuthorizationService,
    readonly viewerBridge:ViewerBridgeService,
    readonly apiV3Service:APIV3Service,
    readonly wpCreate:WorkPackageCreateService,
    readonly notifications:NotificationsService,
    readonly cdRef:ChangeDetectorRef,
    readonly I18n:I18nService,
    readonly viewpointsService:ViewpointsService) {
    super();
  }

  ngAfterViewInit():void {
    // Observe changes on the work package to update the viewpoints
    this.observeChanges();
  }

  ngOnInit() {
    this.viewerBridge.viewerVisible$.subscribe((visible:boolean) => {
      if (visible) {
        this.viewerVisible = true;
      } else {
        this.viewerVisible = false;
      }
      this.cdRef.detectChanges();
    });
  }

  protected observeChanges() {
    this
      .apiV3Service
      .work_packages
      .id(this.workPackage)
      .requireAndStream()
      .pipe(this.untilDestroyed())
      .subscribe(async (wp) => {
        this.workPackage = wp;

        if (!this.projectId) {
          await this.initialize(this.workPackage);
        }

        if (wp.bcfViewpoints) {
          this.refreshViewpoints(wp.bcfViewpoints);
        }
      });
  }

  async initialize(workPackage:WorkPackageResource) {
    this.projectId = idFromLink(workPackage.project.href);
    this.viewAllowed = await this.bcfAuthorization.isAllowedTo(this.projectId, 'project_actions', 'viewTopic');
    this.createAllowed = await this.bcfAuthorization.isAllowedTo(this.projectId, 'topic_actions', 'createViewpoint');

    this.loadViewpointFromRoute(workPackage);
    this.cdRef.detectChanges();
  }

  refreshViewpoints(viewpoints:HalLink[]) {
    this.viewpoints = viewpoints.map((el:HalLink) => ({ href: el.href, snapshotURL: `${el.href}/snapshot` }));

    this.setViewpointsOnGallery(this.viewpoints);
  }

  protected showViewpoint(workPackage:WorkPackageResource, index:number) {
    this.viewerBridge.showViewpoint(workPackage, index);
  }

  protected deleteViewpoint(workPackage:WorkPackageResource, index:number) {
    if (!window.confirm(this.text.text_are_you_sure)) {
      return;
    }

    this.viewpointsService
      .deleteViewPoint$(workPackage, index)
      .subscribe((data) => {
        this.notifications.addSuccess(this.text.notice_successful_delete);
        this.gallery.preview.close();
      });
  }

  public saveViewpoint(workPackage:WorkPackageResource) {
    this.viewpointsService
      .saveViewpoint$(workPackage)
      .subscribe((viewpoint) => {
        this.notifications.addSuccess(this.text.notice_successful_create);
        this.showIndex = this.viewpoints.length;
      });
  }

  protected loadViewpointFromRoute(workPackage:WorkPackageResource) {
    if (typeof (this.state.params.viewpoint) === 'number') {
      const index = this.state.params.viewpoint;
      this.showViewpoint(workPackage, index);
      this.showIndex = index;
      this.selectViewpointInGallery();
      this.state.go('.', { ...this.state.params, viewpoint: undefined }, { reload: false });
    }
  }

  public shouldShowGroup() {
    return this.viewAllowed
      && (this.viewpoints.length > 0
        || (this.createAllowed && this.viewerVisible));
  }

  // Gallery functionality
  protected actions() {
    return [
      {
        icon: 'icon-view-model',
        onClick: (evt:any, index:number) => {
          this.showViewpoint(this.workPackage, index);
          this.gallery.preview.close();
        },
        titleText: this.text.show_viewpoint,
      },
      {
        icon: 'icon-delete',
        onClick: (evt:any, index:number) => this.deleteViewpoint(this.workPackage, index),
        titleText: this.text.delete_viewpoint,
      },
    ];
  }

  // eslint-disable-next-line class-methods-use-this
  public galleryPreviewOpen():void {
    jQuery('.op-app-header').addClass('-no-z-index');
  }

  // eslint-disable-next-line class-methods-use-this
  public galleryPreviewClose():void {
    jQuery('.op-app-header').removeClass('-no-z-index');
  }

  public selectViewpointInGallery() {
    setTimeout(() => this.gallery?.show(this.showIndex), 250);
  }

  public onGalleryChanged(event:{ index:number }) {
    this.showIndex = event.index;
  }

  protected set showIndex(value:number) {
    const options = [...this.galleryOptions];
    options[0].startIndex = value;
    this.galleryOptions = options;
  }

  protected get showIndex():number {
    return this.galleryOptions[0].startIndex!;
  }

  protected setViewpointsOnGallery(viewpoints:BcfViewpointItem[]) {
    const { length } = viewpoints;

    this.setThumbnailProperties(length);

    if (this.showIndex < 0 || length < 1) {
      this.showIndex = 0;
    } else if (this.showIndex >= length) {
      this.showIndex = length - 1;
    }

    this.galleryImages = viewpoints.map((viewpoint) => ({
      small: viewpoint.snapshotURL,
      medium: viewpoint.snapshotURL,
      big: viewpoint.snapshotURL,
    }));
    this.cdRef.detectChanges();
  }

  protected setThumbnailProperties(viewpointCount:number) {
    const options = [...this.galleryOptions];

    options[0].thumbnailsColumns = viewpointCount < 5 ? viewpointCount : 4;
    options[1].thumbnailsColumns = viewpointCount < 5 ? viewpointCount : 4;
    options[2].thumbnailsColumns = viewpointCount < 4 ? viewpointCount : 3;

    options[0].height = `${this.dynamicThumbnailHeight(viewpointCount)}px`;
    options[1].height = `${this.dynamicThumbnailHeight(viewpointCount)}px`;
    options[2].height = `${this.dynamicThumbnailHeight(viewpointCount)}px`;

    this.galleryOptions = options;
  }

  protected dynamicThumbnailHeight(viewpointCount:number):number {
    return Math.max(Math.round(300 / viewpointCount), 120);
  }
}
