package com.swu.guide.modules.spot.service;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.spot.entity.Spot;

public interface SpotService extends IService<Spot> {

    Page<Spot> searchSpot(String keyword, int page, int size);

}
